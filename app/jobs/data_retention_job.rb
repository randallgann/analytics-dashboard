class DataRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 30

  def perform
    cutoff = RETENTION_DAYS.days.ago.to_date
    deleted = GitHubMetric.where("recorded_on < ?", cutoff).delete_all
    deleted_social = SocialPost.where("published_at < ?", cutoff.beginning_of_day).delete_all
    Rails.logger.info "DataRetentionJob: pruned #{deleted} GitHubMetric, #{deleted_social} SocialPost records older than #{cutoff}"
  end
end
