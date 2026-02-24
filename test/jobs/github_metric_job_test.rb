require "test_helper"
require "ostruct"

class GithubMetricJobTest < ActiveSupport::TestCase
  # Build a fake GithubClient stub with all methods needed for the job.
  def build_mock_client(overrides = {})
    today = Date.today

    fake_repo = OpenStruct.new(stargazers_count: 100, forks_count: 50)

    # Two weeks of commit activity (enough to cover the last(5) call)
    # week epoch for 2 weeks ago, days array = 7 values (Sun..Sat)
    week1_start = (today - 14).beginning_of_week(:sunday)
    week2_start = (today - 7).beginning_of_week(:sunday)
    fake_stats = [
      { week: week1_start.to_time.to_i, days: [1, 2, 3, 4, 5, 6, 7], total: 28 },
      { week: week2_start.to_time.to_i, days: [0, 1, 2, 0, 1, 0, 2], total: 6  }
    ]

    # 3 contributors
    fake_contributors = [ OpenStruct.new(total: 10), OpenStruct.new(total: 5), OpenStruct.new(total: 2) ]

    # A release published 5 days ago (within 30-day window)
    fake_release = OpenStruct.new(published_at: 5.days.ago)

    # Two releases: one 5 days ago (within window), one 40 days ago (outside)
    fake_releases = [
      OpenStruct.new(published_at: 5.days.ago),
      OpenStruct.new(published_at: 40.days.ago)
    ]

    client = GithubClient.allocate  # skip initialize (avoids credential lookup)

    defaults = {
      repository:           fake_repo,
      open_issues_count:    10,
      closed_issues_count:  20,
      pull_requests_count:  { open: 3, merged: 5, closed: 2 },
      commit_activity_stats: fake_stats,
      contributors_stats:   fake_contributors,
      contributors_count:   3,
      latest_release:       fake_release,
      releases:             fake_releases
    }
    opts = defaults.merge(overrides)

    client.define_singleton_method(:repository)           { opts[:repository] }
    client.define_singleton_method(:open_issues_count)    { opts[:open_issues_count] }
    client.define_singleton_method(:closed_issues_count)  { opts[:closed_issues_count] }
    client.define_singleton_method(:pull_requests_count) do |state:|
      opts[:pull_requests_count][state.to_sym]
    end
    client.define_singleton_method(:commit_activity_stats) { opts[:commit_activity_stats] }
    client.define_singleton_method(:contributors_stats)    { opts[:contributors_stats] }
    client.define_singleton_method(:contributors_count)    { opts[:contributors_count] }
    client.define_singleton_method(:latest_release)        { opts[:latest_release] }
    client.define_singleton_method(:releases)              { opts[:releases] }

    client
  end

  # Patch GithubClient.new to return the given client object for the duration of a block.
  def with_mock_client(client)
    GithubClient.define_singleton_method(:new) { client }
    yield
  ensure
    GithubClient.singleton_class.remove_method(:new)
  end

  # ----------------------------------------------------------------
  # Core functionality tests
  # ----------------------------------------------------------------

  test "perform creates star and fork records" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert GitHubMetric.where(metric_type: "stars").exists?
    assert GitHubMetric.where(metric_type: "forks").exists?
    assert_equal 100, GitHubMetric.latest_value("stars").to_i
    assert_equal 50,  GitHubMetric.latest_value("forks").to_i
  end

  test "perform creates issue and PR records" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert_equal 10, GitHubMetric.latest_value("open_issues").to_i
    assert_equal 20, GitHubMetric.latest_value("closed_issues").to_i
    assert_equal 3,  GitHubMetric.latest_value("open_prs").to_i
    assert_equal 5,  GitHubMetric.latest_value("merged_prs").to_i
    assert_equal 2,  GitHubMetric.latest_value("closed_prs").to_i
  end

  test "perform creates commit_frequency records from weekly stats" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert GitHubMetric.where(metric_type: "commit_frequency").exists?,
           "Expected commit_frequency records to be created"
  end

  test "perform creates contributor_count record" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert_equal 3, GitHubMetric.latest_value("contributor_count").to_i
  end

  test "perform creates latest_release_date record" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert GitHubMetric.where(metric_type: "latest_release_date").exists?
  end

  test "perform stores release_cadence as count of releases in last 30 days" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    # Two releases provided: one 5 days ago (in window), one 40 days ago (out of window)
    assert_equal 1, GitHubMetric.latest_value("release_cadence").to_i
  end

  test "release_cadence is 0 when no releases in last 30 days" do
    old_releases = [
      OpenStruct.new(published_at: 40.days.ago),
      OpenStruct.new(published_at: 60.days.ago)
    ]
    client = build_mock_client(releases: old_releases)
    with_mock_client(client) do
      GithubMetricJob.perform_now
    end
    assert_equal 0, GitHubMetric.latest_value("release_cadence").to_i
  end

  # ----------------------------------------------------------------
  # Error isolation tests
  # ----------------------------------------------------------------

  test "RateLimitError during one metric does not prevent other metrics from saving" do
    # open_issues_count raises RateLimitError; all other metrics should still save
    client = build_mock_client
    client.define_singleton_method(:open_issues_count) { raise GithubClient::RateLimitError, "rate limited" }

    with_mock_client(client) do
      GithubMetricJob.perform_now
    end

    # These should still be created despite open_issues failing
    assert GitHubMetric.where(metric_type: "stars").exists?,          "stars should be saved"
    assert GitHubMetric.where(metric_type: "forks").exists?,          "forks should be saved"
    assert GitHubMetric.where(metric_type: "closed_issues").exists?,  "closed_issues should be saved"
    assert GitHubMetric.where(metric_type: "open_prs").exists?,       "open_prs should be saved"
    # open_issues should be absent since it raised
    assert_not GitHubMetric.where(metric_type: "open_issues").exists?, "open_issues should not be saved when rate limited"
  end

  test "StatsUnavailableError during one metric does not crash the job" do
    client = build_mock_client
    client.define_singleton_method(:commit_activity_stats) { raise GithubClient::StatsUnavailableError, "not ready" }

    with_mock_client(client) do
      assert_nothing_raised { GithubMetricJob.perform_now }
    end

    # Other metrics should still be present
    assert GitHubMetric.where(metric_type: "stars").exists?
  end

  test "top-level RateLimitError is caught and does not re-raise" do
    client = build_mock_client
    client.define_singleton_method(:repository) { raise GithubClient::RateLimitError, "global rate limit" }

    with_mock_client(client) do
      # Must not raise — rate limit is handled gracefully at the top level
      assert_nothing_raised { GithubMetricJob.perform_now }
    end
  end

  test "top-level StandardError is re-raised for Solid Queue retry handling" do
    client = build_mock_client
    client.define_singleton_method(:repository) { raise StandardError, "unexpected error" }

    with_mock_client(client) do
      assert_raises(StandardError) { GithubMetricJob.perform_now }
    end
  end

  # ----------------------------------------------------------------
  # Idempotency (find_or_create_by! does not duplicate on second run)
  # ----------------------------------------------------------------

  test "running perform_now twice does not create duplicate records for same day" do
    client = build_mock_client
    with_mock_client(client) do
      GithubMetricJob.perform_now
      GithubMetricJob.perform_now
    end
    star_count = GitHubMetric.where(metric_type: "stars", recorded_on: Date.today).count
    assert_equal 1, star_count, "Expected exactly 1 stars record for today after two runs"
  end
end
