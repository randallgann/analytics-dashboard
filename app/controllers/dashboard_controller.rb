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

    # Hero metrics: 7-day deltas (DASH-01)
    @stars_delta  = GitHubMetric.delta_value("stars")
    @forks_delta  = GitHubMetric.delta_value("forks")
    @issues_delta = GitHubMetric.delta_value("open_issues")

    # Social feed data — engagement-ranked (DASH-03)
    # Single fetch + Ruby partition avoids N+1 (see RESEARCH Pitfall 5)
    @ranked_posts  = SocialPost.ranked_by_engagement(limit: 50)
    @hn_posts      = @ranked_posts.select(&:hn?).first(5)
    @reddit_posts  = @ranked_posts.select(&:reddit?).first(5)
    @youtube_posts = @ranked_posts.select(&:youtube?).first(5)
    # All tab: recency order (not engagement) to avoid YouTube view count domination (RESEARCH Open Question 1)
    @all_posts     = SocialPost.last_30_days.recent_first.limit(15)

    @hn_last_updated     = SocialPost.last_fetched_at("hn")
    @reddit_last_updated = SocialPost.last_fetched_at("reddit")

    # Fetch error state from cache (written by social fetch jobs on failure, cleared on success)
    @hn_fetch_error     = Rails.cache.read("social_fetch_error:hn")
    @reddit_fetch_error = Rails.cache.read("social_fetch_error:reddit")

    # YouTube social feed data (Phase 3)
    @youtube_last_updated = SocialPost.last_fetched_at("youtube")
    @youtube_fetch_error  = Rails.cache.read("social_fetch_error:youtube")
  end
end
