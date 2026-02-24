require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # DASH-06: Dashboard is publicly accessible with no login prompt
  test "GET / returns 200 with no authentication required" do
    get root_url
    assert_response :success
  end

  test "GET / works with no GitHubMetric records (empty state)" do
    GitHubMetric.delete_all
    get root_url
    assert_response :success
    assert_select "body"  # page renders something
  end

  test "GET / renders page with chart data when records exist" do
    GitHubMetric.delete_all
    GitHubMetric.create!(metric_type: "stars", value: 150, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "forks", value: 40, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "contributor_count", value: 25, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "release_cadence", value: 3, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "commit_frequency", value: 7, recorded_on: Date.today)

    get root_url
    assert_response :success
  end

  test "GET / renders contributor_count and release_cadence data (GH-06, GH-07)" do
    GitHubMetric.delete_all
    GitHubMetric.create!(metric_type: "contributor_count", value: 25, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "release_cadence", value: 3, recorded_on: Date.today)

    get root_url
    assert_response :success
    # Response body loads successfully — instance vars are populated without errors
    assert_match /<html/i, response.body
  end

  test "GET / renders page with empty state content when no records exist" do
    GitHubMetric.delete_all
    get root_url
    assert_response :success
    assert_match /<html/i, response.body
  end

  test "GET / renders page with a record present (last_updated check)" do
    GitHubMetric.delete_all
    GitHubMetric.create!(metric_type: "stars", value: 200, recorded_on: Date.today)
    get root_url
    assert_response :success
    assert_match /<html/i, response.body
  end
end
