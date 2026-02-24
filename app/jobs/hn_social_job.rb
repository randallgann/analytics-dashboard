class HnSocialJob < ApplicationJob
  queue_as :default

  FETCH_ERROR_KEY = "social_fetch_error:hn"

  def perform
    client = HnClient.new
    posts  = client.search_stories
    now    = Time.current

    count = 0
    posts.each do |post|
      attrs = post.merge(
        platform:   "hn",
        fetched_at: now,
        created_at: now,
        updated_at: now
      )
      SocialPost.upsert(attrs, unique_by: [:platform, :external_id])
      count += 1
    end

    Rails.cache.delete(FETCH_ERROR_KEY)
    Rails.logger.info "HnSocialJob: upserted #{count} HN posts"
  rescue HnClient::FetchError => e
    Rails.logger.error "HnSocialJob: fetch failed — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
    # Do not re-raise — job will run again in 2 hours, transient failures are acceptable
  rescue StandardError => e
    Rails.logger.error "HnSocialJob: unexpected error — #{e.class}: #{e.message}"
    raise
  end
end
