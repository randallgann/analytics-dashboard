require "test_helper"

class YoutubeSocialJobTest < ActiveSupport::TestCase
  SAMPLE_VIDEOS = [
    {
      external_id:   "yt_vid001",
      title:         "OpenClaw Getting Started",
      url:           "https://www.youtube.com/watch?v=yt_vid001",
      author:        "DevChannel",
      score:         14523,
      comment_count: 0,
      subreddit:     nil,
      published_at:  1.day.ago
    },
    {
      external_id:   "yt_vid002",
      title:         "OpenClaw Advanced Usage",
      url:           "https://www.youtube.com/watch?v=yt_vid002",
      author:        "TechTutorials",
      score:         8900,
      comment_count: 0,
      subreddit:     nil,
      published_at:  3.days.ago
    }
  ].freeze

  # Override YoutubeClient.new on the singleton class to return a test double for the block duration.
  def with_mock_youtube_client(videos: SAMPLE_VIDEOS)
    fake = YoutubeClient.allocate
    fake.define_singleton_method(:search_videos) { videos }

    YoutubeClient.define_singleton_method(:new) { fake }
    yield fake
  ensure
    YoutubeClient.singleton_class.remove_method(:new)
  end

  # ----------------------------------------------------------------
  # Core functionality
  # ----------------------------------------------------------------

  test "upserts YouTube posts into SocialPost" do
    with_mock_youtube_client do
      YoutubeSocialJob.perform_now
    end

    assert SocialPost.where(platform: "youtube", external_id: "yt_vid001").exists?,
           "Expected SocialPost for yt_vid001 to be created"
    assert SocialPost.where(platform: "youtube", external_id: "yt_vid002").exists?,
           "Expected SocialPost for yt_vid002 to be created"
  end

  test "upsert is idempotent — running twice with same videos does not duplicate" do
    with_mock_youtube_client do
      YoutubeSocialJob.perform_now
    end

    count_after_first = SocialPost.for_platform("youtube").count

    with_mock_youtube_client do
      YoutubeSocialJob.perform_now
    end

    assert_equal count_after_first, SocialPost.for_platform("youtube").count,
                 "Expected upsert to be idempotent — no duplicate records on second run"
  end

  # ----------------------------------------------------------------
  # Error handling
  # ----------------------------------------------------------------

  test "AuthError is silenced and writes to cache" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    YoutubeClient.define_singleton_method(:new) do
      fake = YoutubeClient.allocate
      fake.define_singleton_method(:search_videos) { raise YoutubeClient::AuthError, "key invalid" }
      fake
    end

    assert_nothing_raised { YoutubeSocialJob.perform_now }
    assert_equal "key invalid", Rails.cache.read("social_fetch_error:youtube"),
                 "Expected AuthError message to be written to cache"
  ensure
    YoutubeClient.singleton_class.remove_method(:new) if YoutubeClient.singleton_class.method_defined?(:new, false)
    Rails.cache = original_cache
  end

  test "FetchError is silenced and writes to cache" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    YoutubeClient.define_singleton_method(:new) do
      fake = YoutubeClient.allocate
      fake.define_singleton_method(:search_videos) { raise YoutubeClient::FetchError, "connection refused" }
      fake
    end

    assert_nothing_raised { YoutubeSocialJob.perform_now }
    assert_equal "connection refused", Rails.cache.read("social_fetch_error:youtube"),
                 "Expected FetchError message to be written to cache"
  ensure
    YoutubeClient.singleton_class.remove_method(:new) if YoutubeClient.singleton_class.method_defined?(:new, false)
    Rails.cache = original_cache
  end

  test "cache cleared on successful fetch" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write("social_fetch_error:youtube", "previous error", expires_in: 6.hours)

    with_mock_youtube_client do
      YoutubeSocialJob.perform_now
    end

    assert_nil Rails.cache.read("social_fetch_error:youtube"),
               "Expected error key to be cleared after successful fetch"
  ensure
    Rails.cache = original_cache
  end
end
