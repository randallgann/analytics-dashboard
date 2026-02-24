class GithubMetricJob < ApplicationJob
  queue_as :default

  def perform
    client = GithubClient.new
    today = Date.today

    record_snapshot(client, today)
    record_commit_activity(client, today)
    record_contributor_count(client, today)
    record_release_info(client, today)
    record_release_cadence(client, today)
  rescue GithubClient::RateLimitError => e
    Rails.logger.error "GithubMetricJob: rate limit hit, will retry in 6 hours: #{e.message}"
    # Do not re-raise — job will run again on its recurring schedule
  rescue => e
    Rails.logger.error "GithubMetricJob failed: #{e.class}: #{e.message}"
    raise # Re-raise to let Solid Queue handle retry
  end

  private

  def record_snapshot(client, today)
    repo = client.repository
    upsert(metric_type: "stars",  value: repo.stargazers_count, recorded_on: today)
    upsert(metric_type: "forks",  value: repo.forks_count,      recorded_on: today)

    upsert(metric_type: "open_issues",   value: safe_call { client.open_issues_count },                    recorded_on: today)
    upsert(metric_type: "closed_issues", value: safe_call { client.closed_issues_count },                  recorded_on: today)
    upsert(metric_type: "open_prs",      value: safe_call { client.pull_requests_count(state: "open") },   recorded_on: today)
    upsert(metric_type: "merged_prs",    value: safe_call { client.pull_requests_count(state: "merged") }, recorded_on: today)
    upsert(metric_type: "closed_prs",    value: safe_call { client.pull_requests_count(state: "closed") }, recorded_on: today)
  end

  # Extracts commit activity from the stats endpoint's 52-week array into daily rows.
  # Takes the last 5 weeks to cover the 30-day window.
  # Uses safe_call so StatsUnavailableError (GitHub 202/retry exhausted) does not crash the job.
  def record_commit_activity(client, today)
    stats = safe_call { client.commit_activity_stats }
    return if stats.blank?

    # Each entry: { week: epoch_int, days: [sun, mon, tue, wed, thu, fri, sat], total: N }
    # Keys may be symbols or strings depending on Sawyer response object.
    stats.last(5).each do |week_stat|
      week_epoch = week_stat[:week] || week_stat["week"]
      week_start = Time.at(week_epoch).utc.to_date
      days = week_stat[:days] || week_stat["days"]
      days.each_with_index do |count, day_index|
        date = week_start + day_index
        next if date > today
        next if date < 30.days.ago.to_date
        upsert(metric_type: "commit_frequency", value: count, recorded_on: date)
      end
    end
  end

  # Stores a daily contributor_count snapshot, enabling a 30-day growth trend (GH-06).
  # Uses contributors_count (list endpoint with Link header) instead of
  # contributors_stats, which is capped at 100 results by GitHub.
  def record_contributor_count(client, today)
    count = safe_call { client.contributors_count }
    return if count.blank?
    upsert(metric_type: "contributor_count", value: count, recorded_on: today)
  end

  # Stores latest release date as a Julian Day Number for numeric storage.
  def record_release_info(client, today)
    release = client.latest_release
    return if release.nil?
    upsert(metric_type: "latest_release_date", value: release.published_at.to_date.jd, recorded_on: today)
  end

  # Stores the count of releases published in the trailing 30-day window (GH-07).
  def record_release_cadence(client, today)
    releases = safe_call { client.releases }
    return if releases.blank?
    recent = releases.select { |r| r.published_at&.to_date&.>=(30.days.ago.to_date) }.count
    upsert(metric_type: "release_cadence", value: recent, recorded_on: today)
  end

  def upsert(metric_type:, value:, recorded_on:)
    return if value.nil?
    metric = GitHubMetric.find_or_initialize_by(metric_type: metric_type, recorded_on: recorded_on)
    metric.value = value
    metric.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "GithubMetricJob: skipping invalid metric #{metric_type}: #{e.message}"
  end

  def safe_call(&block)
    block.call
  rescue GithubClient::RateLimitError, GithubClient::StatsUnavailableError => e
    Rails.logger.warn "GithubMetricJob: metric fetch failed (#{e.class}): #{e.message}"
    nil
  end
end
