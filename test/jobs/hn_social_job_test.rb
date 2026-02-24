require "test_helper"

class HnSocialJobTest < ActiveSupport::TestCase
  SAMPLE_POSTS = [
    {
      external_id:   "123456",
      title:         "OpenClaw is the best",
      url:           "https://openclaw.io",
      author:        "test_user",
      score:         42,
      comment_count: 10,
      subreddit:     nil,
      published_at:  1.day.ago
    },
    {
      external_id:   "789012",
      title:         "OpenClaw — Ask HN",
      url:           "https://news.ycombinator.com/item?id=789012",
      author:        "another_user",
      score:         15,
      comment_count: 3,
      subreddit:     nil,
      published_at:  2.days.ago
    }
  ].freeze

  # Override HnClient.new on the singleton class to return a test double for the block duration.
  def with_mock_hn_client(stories: SAMPLE_POSTS)
    fake = HnClient.allocate
    fake.define_singleton_method(:search_stories) { stories }

    HnClient.define_singleton_method(:new) { fake }
    yield fake
  ensure
    HnClient.singleton_class.remove_method(:new)
  end

  # ----------------------------------------------------------------
  # Core functionality
  # ----------------------------------------------------------------

  test "job creates SocialPost records with platform hn" do
    with_mock_hn_client do
      HnSocialJob.perform_now
    end

    assert SocialPost.where(platform: "hn", external_id: "123456").exists?,
           "Expected SocialPost for external_id 123456 to be created"
    assert SocialPost.where(platform: "hn", external_id: "789012").exists?,
           "Expected SocialPost for external_id 789012 to be created"
  end

  test "job upserts existing record updating score when run twice with different score" do
    with_mock_hn_client(stories: [ SAMPLE_POSTS.first ]) do
      HnSocialJob.perform_now
    end

    assert_equal 42, SocialPost.find_by(platform: "hn", external_id: "123456").score

    updated_post = SAMPLE_POSTS.first.merge(score: 99)
    with_mock_hn_client(stories: [ updated_post ]) do
      HnSocialJob.perform_now
    end

    assert_equal 99, SocialPost.find_by(platform: "hn", external_id: "123456").score,
                 "Expected score to be updated on second upsert"
    assert_equal 1, SocialPost.where(platform: "hn", external_id: "123456").count,
                 "Expected only one record (upsert, not duplicate)"
  end

  # ----------------------------------------------------------------
  # Error handling
  # ----------------------------------------------------------------

  test "FetchError is caught and does not raise" do
    HnClient.define_singleton_method(:new) do
      fake = HnClient.allocate
      fake.define_singleton_method(:search_stories) { raise HnClient::FetchError, "API error" }
      fake
    end

    assert_nothing_raised { HnSocialJob.perform_now }
  ensure
    HnClient.singleton_class.remove_method(:new)
  end

  test "FetchError writes error to Rails.cache under social_fetch_error:hn key" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    HnClient.define_singleton_method(:new) do
      fake = HnClient.allocate
      fake.define_singleton_method(:search_stories) { raise HnClient::FetchError, "timed out" }
      fake
    end

    HnSocialJob.perform_now

    assert_equal "timed out", Rails.cache.read("social_fetch_error:hn"),
                 "Expected error message to be written to cache"
  ensure
    HnClient.singleton_class.remove_method(:new) if HnClient.singleton_class.method_defined?(:new, false)
    Rails.cache = original_cache
  end

  test "successful fetch clears Rails.cache social_fetch_error:hn key" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("social_fetch_error:hn", "previous error", expires_in: 6.hours)

    with_mock_hn_client do
      HnSocialJob.perform_now
    end

    assert_nil Rails.cache.read("social_fetch_error:hn"),
               "Expected error key to be cleared after successful fetch"
  ensure
    Rails.cache = original_cache
  end

  # ----------------------------------------------------------------
  # Logging
  # ----------------------------------------------------------------

  test "log output includes upserted count" do
    io = StringIO.new
    test_logger = Logger.new(io)
    original_logger = Rails.logger
    Rails.logger = test_logger

    with_mock_hn_client do
      HnSocialJob.perform_now
    end

    io.rewind
    log_output = io.read
    assert_match(/HnSocialJob: upserted \d+ HN posts/, log_output)
  ensure
    Rails.logger = original_logger
  end
end
