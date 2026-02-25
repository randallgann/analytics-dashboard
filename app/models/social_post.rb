class SocialPost < ApplicationRecord
  PLATFORMS = %w[hn reddit youtube].freeze
  GRAVITY = 1.8

  validates :platform,    inclusion: { in: PLATFORMS }
  validates :external_id, presence: true, uniqueness: { scope: :platform }
  validates :title,       presence: true
  validates :fetched_at,  presence: true

  scope :for_platform,  ->(p) { where(platform: p) }
  scope :top_posts,     ->(n) { order(score: :desc).limit(n) }
  scope :last_30_days,  -> { where("published_at > ?", 30.days.ago) }
  scope :recent_first,  -> { order(published_at: :desc) }

  # Returns the most recent fetched_at timestamp for the given platform, or nil
  def self.last_fetched_at(platform)
    for_platform(platform).order(fetched_at: :desc).first&.fetched_at
  end

  # Returns posts sorted by HN-style time-decay engagement formula.
  # Returns a plain Array (NOT ActiveRecord::Relation) — do NOT chain .where on the result.
  def self.ranked_by_engagement(limit: 50)
    candidates = last_30_days.where.not(published_at: nil)
    candidates.sort_by do |post|
      age_hours  = [(Time.current - post.published_at) / 3600.0, 0].max
      engagement = post.score.to_f + (post.comment_count.to_f * 2)
      -(engagement / ((age_hours + 2)**GRAVITY))
    end.first(limit)
  end

  def hn?
    platform == "hn"
  end

  def reddit?
    platform == "reddit"
  end

  def youtube?
    platform == "youtube"
  end

  def hn_discussion_url
    "https://news.ycombinator.com/item?id=#{external_id}"
  end
end
