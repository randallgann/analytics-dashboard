class GithubClient
  # Typed error classes for wrapping Octokit exceptions
  class RateLimitError < StandardError; end
  class AuthError < StandardError; end
  class NotFoundError < StandardError; end
  class StatsUnavailableError < StandardError; end

  REPO_SLUG = (Rails.application.credentials.dig(:github, :repo_slug) ||
               ENV.fetch("GITHUB_REPO_SLUG", "openclaw/openclaw")).freeze

  def initialize
    token = Rails.application.credentials.dig(:github, :token) || ENV["GITHUB_TOKEN"]
    @client = Octokit::Client.new(access_token: token)
  end

  # Fetches basic repository data
  def repository
    @client.repository(REPO_SLUG)
  rescue Octokit::Unauthorized => e
    raise AuthError, e.message
  rescue Octokit::NotFound => e
    raise NotFoundError, e.message
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, e.message
  end

  # Returns weekly commit activity (array of week objects)
  def commit_activity_stats
    fetch_stats { @client.commit_activity_stats(REPO_SLUG) }
  end

  # Returns contributor stats (array of contributor objects)
  def contributors_stats
    fetch_stats { @client.contributors_stats(REPO_SLUG) }
  end

  # Returns count of open issues (excludes PRs via Search API — Pitfall 1)
  def open_issues_count
    @client.search_issues("repo:#{REPO_SLUG} is:issue is:open").total_count
  end

  # Returns count of closed issues (excludes PRs via Search API)
  def closed_issues_count
    @client.search_issues("repo:#{REPO_SLUG} is:issue is:closed").total_count
  end

  # Returns PR count by state (:open, :closed, :merged)
  def pull_requests_count(state:)
    @client.search_issues("repo:#{REPO_SLUG} is:pr is:#{state}").total_count
  end

  # Returns the latest release, or nil if none exist
  def latest_release
    @client.latest_release(REPO_SLUG)
  rescue Octokit::NotFound
    nil
  end

  # Returns all releases for computing cadence
  def releases
    @client.releases(REPO_SLUG)
  end

  private

  # Retries stats endpoint on empty/nil response (GitHub returns 202 while computing)
  # Raises StatsUnavailableError after 3 retries.
  def fetch_stats
    retries = 0
    loop do
      result = yield
      return result if result.present?
      retries += 1
      raise StatsUnavailableError, "GitHub stats unavailable after #{retries} retries" if retries >= 3
      sleep(2**retries)
    end
  end
end
