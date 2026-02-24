require "net/http"
require "uri"
require "json"
require "time"

class RedditClient
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end

  SEARCH_URL  = "https://www.reddit.com/search.json"
  USER_AGENT  = "openclaw-analytics/1.0 (by /u/openclaw_bot)"
  SEARCH_TERM = '"OpenClaw"'

  # Fetches and returns an array of normalized post hashes from Reddit search.
  # Uses Reddit's public JSON endpoint — no OAuth credentials required.
  def search_posts
    uri = URI(SEARCH_URL)
    uri.query = URI.encode_www_form(
      q:    SEARCH_TERM,
      sort: "top",
      t:    "month",
      limit: 50,
      type: "link"
    )

    http         = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request              = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = http.request(request)

    if response.code == "429"
      Rails.logger.warn "RedditClient: rate limited (429), returning empty result"
      return []
    end

    raise FetchError, "Reddit search returned #{response.code}" unless response.code == "200"

    body = JSON.parse(response.body)
    children = body.dig("data", "children") || []
    children.map { |child| normalize(child["data"]) }
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "Reddit search connection failed: #{e.message}"
  end

  private

  def normalize(post)
    {
      external_id:   post["id"],
      title:         post["title"],
      url:           post["url"],
      author:        post["author"],
      score:         post["ups"].to_i,
      comment_count: post["num_comments"].to_i,
      subreddit:     post["subreddit"],
      published_at:  post["created_utc"] ? Time.at(post["created_utc"].to_i).utc : nil
    }
  end
end
