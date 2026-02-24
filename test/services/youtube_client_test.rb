require "test_helper"

class YoutubeClientTest < ActiveSupport::TestCase
  # Sample snippet hash matching internal fetch_search_results shape
  SAMPLE_SNIPPET = {
    video_id:     "abc123xyz",
    title:        "OpenClaw: Getting Started Tutorial",
    channel_name: "DevChannel",
    published_at: Time.parse("2025-12-20T14:00:00Z")
  }.freeze

  SAMPLE_VIEW_COUNT = 14523

  # Test that normalize produces correct hash from snippet + view_count
  test "normalize produces correct hash from sample snippet" do
    client = YoutubeClient.allocate
    result = client.send(:normalize, SAMPLE_SNIPPET, SAMPLE_VIEW_COUNT)

    assert_equal "abc123xyz",                                   result[:external_id]
    assert_equal "OpenClaw: Getting Started Tutorial",          result[:title]
    assert_equal "https://www.youtube.com/watch?v=abc123xyz",  result[:url]
    assert_equal "DevChannel",                                  result[:author]
    assert_equal 14523,                                         result[:score]
    assert_equal 0,                                             result[:comment_count]
    assert_nil result[:subreddit]
    assert_kind_of Time,                                        result[:published_at]
    assert_equal 2025,                                          result[:published_at].year
  end

  # Test that FetchError is raised on non-200 response from search endpoint
  test "search_videos raises FetchError on non-200 response" do
    client = YoutubeClient.allocate
    client.instance_variable_set(:@api_key, "fake_key")

    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "500" }
    fake_response.define_singleton_method(:body) { "{}" }

    Net::HTTP.define_singleton_method(:get_response) { |_uri| fake_response }

    assert_raises(YoutubeClient::FetchError) do
      client.search_videos
    end
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :get_response) rescue nil
  end

  # Test that AuthError is raised when API key is nil
  test "search_videos raises AuthError when api_key is nil" do
    client = YoutubeClient.allocate
    client.instance_variable_set(:@api_key, nil)

    assert_raises(YoutubeClient::AuthError) do
      client.search_videos
    end
  end

  # Test that AuthError is raised on 403 with keyInvalid reason
  test "search_videos raises AuthError on 403 with keyInvalid reason" do
    client = YoutubeClient.allocate
    client.instance_variable_set(:@api_key, "invalid_key")

    error_body = JSON.generate({
      "error" => {
        "errors" => [ { "reason" => "keyInvalid" } ]
      }
    })
    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "403" }
    fake_response.define_singleton_method(:body) { error_body }

    Net::HTTP.define_singleton_method(:get_response) { |_uri| fake_response }

    assert_raises(YoutubeClient::AuthError) do
      client.search_videos
    end
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :get_response) rescue nil
  end

  # Test that RateLimitError is raised on 403 with quotaExceeded reason
  test "search_videos raises RateLimitError on 403 with quotaExceeded reason" do
    client = YoutubeClient.allocate
    client.instance_variable_set(:@api_key, "valid_key")

    error_body = JSON.generate({
      "error" => {
        "errors" => [ { "reason" => "quotaExceeded" } ]
      }
    })
    fake_response = Object.new
    fake_response.define_singleton_method(:code) { "403" }
    fake_response.define_singleton_method(:body) { error_body }

    Net::HTTP.define_singleton_method(:get_response) { |_uri| fake_response }

    assert_raises(YoutubeClient::RateLimitError) do
      client.search_videos
    end
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :get_response) rescue nil
  end
end
