class RedditSocialJob < ApplicationJob
  queue_as :default

  FETCH_ERROR_KEY = "social_fetch_error:reddit"

  def perform
    client = RedditClient.new
    posts  = client.search_posts
    now    = Time.current

    count = 0
    posts.each do |post|
      attrs = post.merge(
        platform:   "reddit",
        fetched_at: now,
        created_at: now,
        updated_at: now
      )
      SocialPost.upsert(attrs, unique_by: [:platform, :external_id])
      count += 1
    end

    Rails.cache.delete(FETCH_ERROR_KEY)
    Rails.logger.info "RedditSocialJob: upserted #{count} Reddit posts"
  rescue RedditClient::AuthError => e
    Rails.logger.error "RedditSocialJob: auth failed — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — missing credentials is a known pre-deployment state; HN feed should work independently
  rescue RedditClient::FetchError => e
    Rails.logger.error "RedditSocialJob: fetch failed — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — transient failure, retry in 2 hours
  rescue RedditClient::RateLimitError => e
    Rails.logger.warn "RedditSocialJob: rate limited — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, "Rate limited", expires_in: 6.hours)
    # Do not re-raise — back off and retry in 2 hours
  rescue StandardError => e
    Rails.logger.error "RedditSocialJob: unexpected error — #{e.class}: #{e.message}"
    raise
  end
end
