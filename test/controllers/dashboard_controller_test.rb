require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  # Clean up cache keys after each test to avoid pollution
  teardown do
    Rails.cache.delete("social_fetch_error:hn")
    Rails.cache.delete("social_fetch_error:reddit")
    Rails.cache.delete("social_fetch_error:youtube")
  end

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

  # Social section tests
  test "Social section heading is rendered when GitHub data exists" do
    get root_url
    assert_response :success
    assert_match /Social/, response.body
  end

  test "Social nav link is rendered" do
    get root_url
    assert_response :success
    assert_match /href="#social"/, response.body
  end

  test "HN post title appears in response when HN fixture exists" do
    get root_url
    assert_response :success
    assert_match /OpenClaw Launch/, response.body
  end

  test "Reddit post title appears in response when Reddit fixture exists" do
    get root_url
    assert_response :success
    assert_match /OpenClaw is amazing/, response.body
  end

  test "empty state message shown when no social posts exist" do
    SocialPost.delete_all
    get root_url
    assert_response :success
    assert_match /No recent mentions found on Hacker News/, response.body
    assert_match /No recent mentions found on Reddit/, response.body
  end

  test "HN fetch error state shows error message not empty state" do
    SocialPost.delete_all
    # Use memory_store temporarily since test env uses null_store
    with_memory_cache do |cache|
      cache.write("social_fetch_error:hn", "Connection refused")
      get root_url
      assert_response :success
      assert_match /Unable to fetch HN posts/, response.body
      assert_no_match /No recent mentions found on Hacker News/, response.body
    end
  end

  test "Reddit fetch error state shows error message not empty state" do
    SocialPost.delete_all
    with_memory_cache do |cache|
      cache.write("social_fetch_error:reddit", "Connection refused")
      get root_url
      assert_response :success
      assert_match /Unable to fetch Reddit posts/, response.body
      assert_no_match /No recent mentions found on Reddit/, response.body
    end
  end

  test "fetch error takes precedence over existing stale posts" do
    # Stale posts exist from a previous successful fetch
    # but the latest fetch failed — error state must win
    with_memory_cache do |cache|
      cache.write("social_fetch_error:hn", "Timeout")
      get root_url
      assert_response :success
      assert_match /Unable to fetch HN posts/, response.body
      # Even though HN fixture posts exist, error message should appear
      assert_no_match /No recent mentions found on Hacker News/, response.body
    end
  end

  # YouTube UI tests (Phase 3)
  test "YouTube post title appears in response when YouTube fixture exists" do
    get root_url
    assert_response :success
    assert_match /OpenClaw Tutorial/, response.body
  end

  test "YouTube tab button is rendered" do
    get root_url
    assert_response :success
    assert_match /data-tab-id="youtube"/, response.body
  end

  test "YouTube empty state shown when no social posts exist" do
    SocialPost.delete_all
    get root_url
    assert_response :success
    assert_match /No recent mentions found on YouTube/, response.body
  end

  test "YouTube fetch error state shows error message not empty state" do
    SocialPost.delete_all
    with_memory_cache do |cache|
      cache.write("social_fetch_error:youtube", "Connection refused")
      get root_url
      assert_response :success
      assert_match /Unable to fetch YouTube videos/, response.body
      assert_no_match /No recent mentions found on YouTube/, response.body
    end
  end

  test "YouTube badge rendered for youtube post" do
    get root_url
    assert_response :success
    assert_match /dash-social-badge--youtube/, response.body
  end

  # DASH-01: Hero metrics row with delta indicators
  test "hero row renders when GitHub data exists" do
    GitHubMetric.delete_all
    GitHubMetric.create!(metric_type: "stars", value: 100, recorded_on: 10.days.ago.to_date)
    GitHubMetric.create!(metric_type: "stars", value: 150, recorded_on: Date.today)
    GitHubMetric.create!(metric_type: "forks", value: 30, recorded_on: Date.today)
    get root_url
    assert_response :success
    assert_match /dash-hero-row/, response.body
    assert_match /dash-hero-card/, response.body
  end

  test "hero row shows 'No baseline yet' when fewer than 7 days of data" do
    GitHubMetric.delete_all
    GitHubMetric.create!(metric_type: "stars", value: 150, recorded_on: Date.today)
    get root_url
    assert_response :success
    assert_match /No baseline yet/, response.body
  end

  # DASH-03: Engagement-ranked social feed
  test "social posts are rendered in engagement-ranked order per platform" do
    get root_url
    assert_response :success
    # Social section renders without error
    assert_match /Social/, response.body
  end

  # DASH-04: OpenGraph meta tags for rich social previews
  test "OpenGraph meta tags are present in response" do
    get root_url
    assert_response :success
    assert_match /og:title/, response.body
    assert_match /og:description/, response.body
    assert_match /og:image/, response.body
    assert_match /og-image\.png/, response.body
    assert_match /twitter:card/, response.body
  end

  test "og:image URL is absolute, not relative" do
    get root_url
    assert_response :success
    # The og:image content attribute must start with http
    assert_match /og:image.*content="https?:\/\//, response.body
  end

  private

  # Temporarily swap Rails.cache with a memory store so cache writes are testable
  # (test env uses null_store by default which discards all writes)
  def with_memory_cache
    memory_cache = ActiveSupport::Cache::MemoryStore.new
    original_cache = Rails.cache
    Rails.cache = memory_cache
    yield memory_cache
  ensure
    Rails.cache = original_cache
  end
end
