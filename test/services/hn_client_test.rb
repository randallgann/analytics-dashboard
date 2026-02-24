require "test_helper"

class HnClientTest < ActiveSupport::TestCase
  # Sample HN hit JSON matching Algolia API shape
  SAMPLE_HIT = {
    "objectID"     => "42001",
    "title"        => "OpenClaw: Open-source analytics for your project",
    "url"          => "https://openclaw.io",
    "author"       => "hn_poster",
    "points"       => 250,
    "num_comments" => 87,
    "created_at"   => "2025-12-20T14:00:00.000Z"
  }.freeze

  # Sample Ask HN hit (no url field)
  SAMPLE_ASKHN_HIT = {
    "objectID"     => "42002",
    "title"        => "Ask HN: What do you think of OpenClaw?",
    "url"          => nil,
    "author"       => "curious_hacker",
    "points"       => 45,
    "num_comments" => 23,
    "created_at"   => "2025-12-21T08:00:00.000Z"
  }.freeze

  # Test that normalize produces correct hash from sample hit JSON
  test "normalize produces correct hash from sample hit" do
    client = HnClient.allocate
    result = client.send(:normalize, SAMPLE_HIT)

    assert_equal "42001",                   result[:external_id]
    assert_equal "OpenClaw: Open-source analytics for your project", result[:title]
    assert_equal "https://openclaw.io",     result[:url]
    assert_equal "hn_poster",               result[:author]
    assert_equal 250,                       result[:score]
    assert_equal 87,                        result[:comment_count]
    assert_nil result[:subreddit]
    assert_kind_of Time,                    result[:published_at]
    assert_equal 2025,                      result[:published_at].year
  end

  # Test that normalize falls back to HN discussion URL when hit["url"] is nil
  test "normalize falls back to HN discussion URL when url is nil" do
    client   = HnClient.allocate
    result   = client.send(:normalize, SAMPLE_ASKHN_HIT)

    expected_fallback = "https://news.ycombinator.com/item?id=42002"
    assert_equal expected_fallback, result[:url]
  end

  # Test that FetchError is raised on non-200 response
  test "search_stories raises FetchError on non-200 response" do
    client = HnClient.new

    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "500" }

    Net::HTTP.define_singleton_method(:get_response) { |_uri| fake_response }

    assert_raises(HnClient::FetchError) do
      client.search_stories
    end
  ensure
    # Restore Net::HTTP.get_response to original after test
    Net::HTTP.singleton_class.send(:remove_method, :get_response) rescue nil
  end
end
