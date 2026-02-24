require "test_helper"

class RedditSocialJobTest < ActiveSupport::TestCase
  SAMPLE_POSTS = [
    {
      external_id:   "abc123",
      title:         "OpenClaw is amazing",
      url:           "https://openclaw.io/blog",
      author:        "reddit_user",
      score:         75,
      comment_count: 18,
      subreddit:     "programming",
      published_at:  1.day.ago
    },
    {
      external_id:   "def456",
      title:         "Anyone tried OpenClaw?",
      url:           "https://reddit.com/r/devops/comments/def456",
      author:        "devops_fan",
      score:         22,
      comment_count: 5,
      subreddit:     "devops",
      published_at:  3.days.ago
    }
  ].freeze

  # Override RedditClient.new on the singleton class to return a test double for the block duration.
  def with_mock_reddit_client(posts: SAMPLE_POSTS)
    fake = RedditClient.allocate
    fake.define_singleton_method(:search_posts) { posts }

    RedditClient.define_singleton_method(:new) { fake }
    yield fake
  ensure
    RedditClient.singleton_class.remove_method(:new)
  end

  # ----------------------------------------------------------------
  # Core functionality
  # ----------------------------------------------------------------

  test "job creates SocialPost records with platform reddit and subreddit populated" do
    with_mock_reddit_client do
      RedditSocialJob.perform_now
    end

    post1 = SocialPost.find_by(platform: "reddit", external_id: "abc123")
    post2 = SocialPost.find_by(platform: "reddit", external_id: "def456")

    assert post1, "Expected SocialPost for external_id abc123 to be created"
    assert_equal "programming", post1.subreddit, "Expected subreddit to be populated"

    assert post2, "Expected SocialPost for external_id def456 to be created"
    assert_equal "devops", post2.subreddit, "Expected subreddit to be populated"
  end

  # ----------------------------------------------------------------
  # Error handling
  # ----------------------------------------------------------------

  test "AuthError is caught and does not raise" do
    RedditClient.define_singleton_method(:new) { raise RedditClient::AuthError, "credentials missing" }

    assert_nothing_raised { RedditSocialJob.perform_now }
  ensure
    RedditClient.singleton_class.remove_method(:new)
  end

  test "AuthError writes error to Rails.cache under social_fetch_error:reddit key" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    RedditClient.define_singleton_method(:new) { raise RedditClient::AuthError, "credentials missing" }

    RedditSocialJob.perform_now

    assert_equal "credentials missing", Rails.cache.read("social_fetch_error:reddit"),
                 "Expected AuthError message to be written to cache"
  ensure
    RedditClient.singleton_class.remove_method(:new) if RedditClient.singleton_class.method_defined?(:new, false)
    Rails.cache = original_cache
  end

  test "FetchError writes error to Rails.cache under social_fetch_error:reddit key" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    RedditClient.define_singleton_method(:new) do
      fake = RedditClient.allocate
      fake.define_singleton_method(:search_posts) { raise RedditClient::FetchError, "connection refused" }
      fake
    end

    RedditSocialJob.perform_now

    assert_equal "connection refused", Rails.cache.read("social_fetch_error:reddit"),
                 "Expected FetchError message to be written to cache"
  ensure
    RedditClient.singleton_class.remove_method(:new) if RedditClient.singleton_class.method_defined?(:new, false)
    Rails.cache = original_cache
  end

  test "successful fetch clears Rails.cache social_fetch_error:reddit key" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("social_fetch_error:reddit", "previous error", expires_in: 6.hours)

    with_mock_reddit_client do
      RedditSocialJob.perform_now
    end

    assert_nil Rails.cache.read("social_fetch_error:reddit"),
               "Expected error key to be cleared after successful fetch"
  ensure
    Rails.cache = original_cache
  end
end
