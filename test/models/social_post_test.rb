require "test_helper"

class SocialPostTest < ActiveSupport::TestCase
  # Valid HN post saves
  test "saves valid HN post" do
    post = SocialPost.new(
      platform: "hn",
      external_id: "12345",
      title: "Test HN Story",
      url: "https://example.com",
      author: "tester",
      score: 100,
      comment_count: 25,
      fetched_at: Time.current
    )
    assert post.save, "Expected HN post to save: #{post.errors.full_messages.inspect}"
  end

  # Valid Reddit post saves with subreddit
  test "saves valid Reddit post with subreddit" do
    post = SocialPost.new(
      platform: "reddit",
      external_id: "xyz999",
      title: "Test Reddit Post",
      url: "https://example.com/r/test",
      author: "redditor",
      score: 50,
      comment_count: 10,
      subreddit: "programming",
      fetched_at: Time.current
    )
    assert post.save, "Expected Reddit post to save: #{post.errors.full_messages.inspect}"
  end

  # Rejects invalid platform
  test "rejects invalid platform" do
    post = SocialPost.new(
      platform: "twitter",
      external_id: "tw001",
      title: "Tweet",
      fetched_at: Time.current
    )
    assert_not post.valid?
    assert_includes post.errors[:platform], "is not included in the list"
  end

  # Rejects duplicate platform + external_id
  test "rejects duplicate platform and external_id" do
    SocialPost.create!(
      platform: "hn",
      external_id: "dup001",
      title: "First Post",
      fetched_at: Time.current
    )
    duplicate = SocialPost.new(
      platform: "hn",
      external_id: "dup001",
      title: "Duplicate Post",
      fetched_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  # Rejects missing title
  test "rejects missing title" do
    post = SocialPost.new(
      platform: "hn",
      external_id: "notitle001",
      fetched_at: Time.current
    )
    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
  end

  # for_platform scope returns correct posts
  test "for_platform scope returns only posts for given platform" do
    hn_count    = SocialPost.for_platform("hn").count
    reddit_count = SocialPost.for_platform("reddit").count
    # Fixtures have 1 hn and 1 reddit post
    assert hn_count >= 1, "Expected at least one HN post from fixtures"
    assert reddit_count >= 1, "Expected at least one Reddit post from fixtures"
    # All returned records match the platform
    assert SocialPost.for_platform("hn").all? { |p| p.platform == "hn" }
    assert SocialPost.for_platform("reddit").all? { |p| p.platform == "reddit" }
  end

  # top_posts scope returns ordered by score desc, limited
  test "top_posts scope returns posts ordered by score desc and limited" do
    # Create posts with known scores
    SocialPost.create!(platform: "hn", external_id: "score_high", title: "High Score", score: 500, fetched_at: Time.current)
    SocialPost.create!(platform: "hn", external_id: "score_low",  title: "Low Score",  score: 1,   fetched_at: Time.current)

    top = SocialPost.top_posts(1)
    assert_equal 1, top.size
    assert top.first.score >= 500, "Expected highest-scored post first"
  end

  # last_fetched_at returns most recent fetched_at for platform
  test "last_fetched_at returns most recent fetched_at for platform" do
    older_time = 2.hours.ago
    newer_time = 1.hour.ago

    SocialPost.create!(platform: "hn", external_id: "fetch_old", title: "Old Fetch", fetched_at: older_time)
    SocialPost.create!(platform: "hn", external_id: "fetch_new", title: "New Fetch", fetched_at: newer_time)

    result = SocialPost.last_fetched_at("hn")
    assert_not_nil result
    # Should be within 5 seconds of newer_time
    assert_in_delta newer_time.to_i, result.to_i, 5
  end

  # hn? predicate
  test "hn? returns true for HN posts" do
    post = social_posts(:hn_post_one)
    assert post.hn?
    assert_not post.reddit?
  end

  # reddit? predicate
  test "reddit? returns true for Reddit posts" do
    post = social_posts(:reddit_post_one)
    assert post.reddit?
    assert_not post.hn?
  end

  # hn_discussion_url constructs correct URL
  test "hn_discussion_url constructs correct URL from external_id" do
    post = social_posts(:hn_post_one)
    expected = "https://news.ycombinator.com/item?id=#{post.external_id}"
    assert_equal expected, post.hn_discussion_url
  end
end
