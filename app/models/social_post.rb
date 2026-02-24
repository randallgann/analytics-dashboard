class SocialPost < ApplicationRecord
  PLATFORMS = %w[hn reddit].freeze

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

  def hn?
    platform == "hn"
  end

  def reddit?
    platform == "reddit"
  end

  def hn_discussion_url
    "https://news.ycombinator.com/item?id=#{external_id}"
  end
end
