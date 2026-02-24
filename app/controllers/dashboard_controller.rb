class DashboardController < ApplicationController
  def index
    # Time-series chart data (30-day rolling)
    @stars_data       = GitHubMetric.chart_data("stars")
    @forks_data       = GitHubMetric.chart_data("forks")
    @commit_data      = GitHubMetric.chart_data("commit_frequency")
    @contributor_data = GitHubMetric.chart_data("contributor_count")  # GH-06: contributor growth trend

    # Latest snapshot values for summary numbers
    @stars_count        = GitHubMetric.latest_value("stars")
    @forks_count        = GitHubMetric.latest_value("forks")
    @open_issues        = GitHubMetric.latest_value("open_issues")
    @closed_issues      = GitHubMetric.latest_value("closed_issues")
    @open_prs           = GitHubMetric.latest_value("open_prs")
    @merged_prs         = GitHubMetric.latest_value("merged_prs")
    @closed_prs         = GitHubMetric.latest_value("closed_prs")
    @contributor_count  = GitHubMetric.latest_value("contributor_count")

    # Latest release info + release cadence (GH-07)
    @latest_release_jd  = GitHubMetric.latest_value("latest_release_date")
    @release_cadence    = GitHubMetric.latest_value("release_cadence")  # GH-07: releases in last 30 days

    # Last updated timestamp (most recent record across all metrics)
    @last_updated = GitHubMetric.order(updated_at: :desc).first&.updated_at

    # Has any data at all?
    @has_data = GitHubMetric.exists?

    # Social feed data (Phase 2)
    @hn_posts     = SocialPost.for_platform("hn").top_posts(5)
    @reddit_posts = SocialPost.for_platform("reddit").top_posts(5)
    @all_posts    = SocialPost.order(score: :desc).limit(10)

    @hn_last_updated     = SocialPost.last_fetched_at("hn")
    @reddit_last_updated = SocialPost.last_fetched_at("reddit")

    # Fetch error state from cache (written by social fetch jobs on failure, cleared on success)
    @hn_fetch_error     = Rails.cache.read("social_fetch_error:hn")
    @reddit_fetch_error = Rails.cache.read("social_fetch_error:reddit")
  end
end
