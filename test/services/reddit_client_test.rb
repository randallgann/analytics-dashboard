require "test_helper"

class RedditClientTest < ActiveSupport::TestCase
  # Sample Reddit post data matching Reddit API shape
  SAMPLE_POST = {
    "id"           => "def456",
    "title"        => "OpenClaw - the analytics dashboard we needed",
    "url"          => "https://openclaw.io/features",
    "author"       => "redditor42",
    "ups"          => 312,
    "num_comments" => 55,
    "subreddit"    => "programming",
    "created_utc"  => 1734566400  # 2024-12-19 00:00:00 UTC
  }.freeze

  # Test that AuthError is raised when no credentials available
  test "raises AuthError when no credentials available" do
    # Save and clear ENV credentials
    original_id     = ENV.delete("REDDIT_CLIENT_ID")
    original_secret = ENV.delete("REDDIT_CLIENT_SECRET")

    assert_raises(RedditClient::AuthError) do
      # Rails credentials won't have reddit keys in test env, so ENV is the only source
      RedditClient.new
    end
  ensure
    ENV["REDDIT_CLIENT_ID"]     = original_id     if original_id
    ENV["REDDIT_CLIENT_SECRET"] = original_secret if original_secret
  end

  # Test that normalize produces correct hash from sample Reddit post JSON
  test "normalize produces correct hash from sample post" do
    client = RedditClient.allocate
    result = client.send(:normalize, SAMPLE_POST)

    assert_equal "def456",                                       result[:external_id]
    assert_equal "OpenClaw - the analytics dashboard we needed", result[:title]
    assert_equal "https://openclaw.io/features",                 result[:url]
    assert_equal "redditor42",                                   result[:author]
    assert_equal 312,                                            result[:score]
    assert_equal 55,                                             result[:comment_count]
    assert_equal "programming",                                  result[:subreddit]
    assert_kind_of Time,                                         result[:published_at]
  end

  # Test that normalize converts created_utc to UTC Time
  test "normalize converts created_utc unix timestamp to UTC Time" do
    client = RedditClient.allocate
    result = client.send(:normalize, SAMPLE_POST)

    expected_time = Time.at(1734566400).utc
    assert_equal expected_time, result[:published_at]
    assert_equal "UTC",         result[:published_at].zone
  end
end
