class GitHubMetric < ApplicationRecord
  self.table_name = "github_metrics"

  METRIC_TYPES = %w[
    stars forks open_issues closed_issues open_prs merged_prs closed_prs
    commit_frequency contributor_count latest_release_date release_cadence
  ].freeze

  validates :metric_type, inclusion: { in: METRIC_TYPES }
  validates :recorded_on, presence: true
  validates :value, presence: true
  validates :metric_type, uniqueness: { scope: :recorded_on }

  scope :for_metric, ->(type) { where(metric_type: type) }
  scope :last_30_days, -> { where(recorded_on: 30.days.ago.to_date..) }
  scope :ordered, -> { order(recorded_on: :asc) }

  def self.chart_data(metric_type)
    for_metric(metric_type).last_30_days.ordered.pluck(:recorded_on, :value).to_h
  end

  def self.latest_value(metric_type)
    for_metric(metric_type).order(recorded_on: :desc).first&.value
  end

  def self.delta_value(metric_type, days: 7)
    current = for_metric(metric_type).order(recorded_on: :desc).first&.value
    past    = for_metric(metric_type)
                .where(recorded_on: ...(Date.today - days))
                .order(recorded_on: :desc)
                .first&.value
    return nil if current.nil? || past.nil?
    current - past
  end
end
