class YoutubeSocialJob < ApplicationJob
  queue_as :default

  FETCH_ERROR_KEY = "social_fetch_error:youtube"

  def perform
    client = YoutubeClient.new
    posts  = client.search_videos
    now    = Time.current

    count = 0
    posts.each do |post|
      attrs = post.merge(
        platform:   "youtube",
        fetched_at: now,
        created_at: now,
        updated_at: now
      )
      SocialPost.upsert(attrs, unique_by: [:platform, :external_id])
      count += 1
    end

    Rails.cache.delete(FETCH_ERROR_KEY)
    Rails.logger.info "YoutubeSocialJob: upserted #{count} YouTube posts"
  rescue YoutubeClient::AuthError => e
    Rails.logger.error "YoutubeSocialJob: auth error — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — missing credentials expected pre-deployment (per Phase 2 decision for Reddit)
  rescue YoutubeClient::RateLimitError => e
    Rails.logger.error "YoutubeSocialJob: rate limit exceeded — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — quota resets daily, job will succeed on next scheduled run
  rescue YoutubeClient::FetchError => e
    Rails.logger.error "YoutubeSocialJob: fetch failed — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — transient failure, job runs again in 6 hours
  rescue StandardError => e
    Rails.logger.error "YoutubeSocialJob: unexpected error — #{e.class}: #{e.message}"
    raise
  end
end
