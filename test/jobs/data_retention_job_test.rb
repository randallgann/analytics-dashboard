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
    assert_match(/DataRetentionJob: pruned \d+ GitHubMetric records older than/, log_output)
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
end
