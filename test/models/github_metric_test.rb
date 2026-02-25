require "test_helper"

class GitHubMetricTest < ActiveSupport::TestCase
  # Valid save test - uses a metric_type not in fixtures
  test "saves with valid attributes" do
    metric = GitHubMetric.new(
      metric_type: "open_prs",
      value: 42.0,
      recorded_on: Date.today
    )
    assert metric.save, "Expected metric to save with valid attributes"
  end

  # Duplicate uniqueness test
  test "rejects duplicate metric_type and recorded_on" do
    date = Date.today - 60  # Far enough in the past to avoid fixture conflicts
    GitHubMetric.create!(metric_type: "closed_prs", value: 10, recorded_on: date)
    duplicate = GitHubMetric.new(metric_type: "closed_prs", value: 20, recorded_on: date)
    assert_not duplicate.valid?, "Expected duplicate to be invalid"
    assert_includes duplicate.errors[:metric_type], "has already been taken"
  end

  # chart_data returns hash of date => value
  test "chart_data returns a hash of date to value" do
    GitHubMetric.create!(metric_type: "open_issues", value: 5, recorded_on: 5.days.ago.to_date)
    GitHubMetric.create!(metric_type: "open_issues", value: 8, recorded_on: 3.days.ago.to_date)

    data = GitHubMetric.chart_data("open_issues")
    assert_kind_of Hash, data
    assert data.size >= 2
    assert data.values.all? { |v| v.is_a?(Numeric) }
  end

  # latest_value returns most recent value
  test "latest_value returns the most recent value for a metric type" do
    GitHubMetric.create!(metric_type: "contributor_count", value: 3, recorded_on: 10.days.ago.to_date)
    GitHubMetric.create!(metric_type: "contributor_count", value: 7, recorded_on: 2.days.ago.to_date)

    latest = GitHubMetric.latest_value("contributor_count")
    assert_equal 7.0, latest.to_f
  end

  # latest_value returns nil for missing metric
  test "latest_value returns nil when no records exist for metric type" do
    assert_nil GitHubMetric.latest_value("merged_prs")
  end

  # Validates metric_type inclusion
  test "rejects invalid metric_type" do
    metric = GitHubMetric.new(metric_type: "invalid_type", value: 10, recorded_on: Date.today)
    assert_not metric.valid?
    assert_includes metric.errors[:metric_type], "is not included in the list"
  end

  # DASH-01: delta_value tests
  test "delta_value returns difference between current and 7-day-old value" do
    GitHubMetric.create!(metric_type: "stars", value: 100, recorded_on: 10.days.ago.to_date)
    GitHubMetric.create!(metric_type: "stars", value: 150, recorded_on: Date.today)
    delta = GitHubMetric.delta_value("stars")
    assert_equal 50, delta.to_i
  end

  test "delta_value returns nil when fewer than 7 days of data" do
    GitHubMetric.create!(metric_type: "commit_frequency", value: 10, recorded_on: Date.today)
    assert_nil GitHubMetric.delta_value("commit_frequency")
  end

  test "delta_value returns nil when no data exists" do
    assert_nil GitHubMetric.delta_value("release_cadence")
  end
end
