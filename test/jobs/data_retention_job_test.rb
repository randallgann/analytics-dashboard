require "test_helper"

class DataRetentionJobTest < ActiveSupport::TestCase
  test "deletes records older than 30 days" do
    old_record    = GitHubMetric.create!(metric_type: "stars", value: 50, recorded_on: 31.days.ago.to_date)
    recent_record = GitHubMetric.create!(metric_type: "forks", value: 10, recorded_on: 29.days.ago.to_date)
    today_record  = GitHubMetric.create!(metric_type: "open_prs", value: 3, recorded_on: Date.today)

    DataRetentionJob.perform_now

    assert_not GitHubMetric.exists?(old_record.id),    "Expected 31-day-old record to be deleted"
    assert     GitHubMetric.exists?(recent_record.id), "Expected 29-day-old record to still exist"
    assert     GitHubMetric.exists?(today_record.id),  "Expected today's record to still exist"
  end

  test "logs a DataRetentionJob pruned message after running" do
    GitHubMetric.create!(metric_type: "merged_prs", value: 100, recorded_on: 31.days.ago.to_date)

    # Swap Rails.logger for a StringIO-backed logger to capture output
    io = StringIO.new
    test_logger = Logger.new(io)
    original_logger = Rails.logger
    Rails.logger = test_logger

    DataRetentionJob.perform_now

    io.rewind
    log_output = io.read
    assert_match(/DataRetentionJob: pruned \d+ GitHubMetric, \d+ SocialPost records older than/, log_output)
  ensure
    Rails.logger = original_logger
  end

  test "does not delete records exactly at the boundary (29 days ago)" do
    boundary_record = GitHubMetric.create!(
      metric_type: "closed_issues",
      value: 15,
      recorded_on: 29.days.ago.to_date
    )

    DataRetentionJob.perform_now

    assert GitHubMetric.exists?(boundary_record.id), "Expected boundary record to be preserved"
  end

  test "does nothing and does not raise when no old records exist" do
    GitHubMetric.create!(metric_type: "contributor_count", value: 5, recorded_on: Date.today)

    assert_nothing_raised { DataRetentionJob.perform_now }

    assert_equal 1, GitHubMetric.count, "Expected one record to remain"
  end

  # ----------------------------------------------------------------
  # SocialPost pruning tests
  # ----------------------------------------------------------------

  test "prunes SocialPost records older than 30 days" do
    old_post = SocialPost.create!(
      platform:    "hn",
      external_id: "old_hn_001",
      title:       "Old OpenClaw post",
      url:         "https://openclaw.io/old",
      published_at: 31.days.ago,
      fetched_at:  31.days.ago
    )
    recent_post = SocialPost.create!(
      platform:    "hn",
      external_id: "recent_hn_001",
      title:       "Recent OpenClaw post",
      url:         "https://openclaw.io/new",
      published_at: 29.days.ago,
      fetched_at:  29.days.ago
    )

    DataRetentionJob.perform_now

    assert_not SocialPost.exists?(old_post.id),    "Expected 31-day-old SocialPost to be deleted"
    assert     SocialPost.exists?(recent_post.id), "Expected 29-day-old SocialPost to be preserved"
  end

  test "preserves SocialPost records within 30 days" do
    today_post = SocialPost.create!(
      platform:    "reddit",
      external_id: "today_rdt_001",
      title:       "Today Reddit post",
      url:         "https://reddit.com/r/prog/today",
      published_at: Time.current,
      fetched_at:  Time.current
    )

    DataRetentionJob.perform_now

    assert SocialPost.exists?(today_post.id), "Expected today's SocialPost to be preserved"
  end
end
