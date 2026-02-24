require "net/http"
require "uri"
require "json"
require "time"
require "base64"

class RedditClient
  class AuthError < StandardError; end
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end

  TOKEN_URL   = "https://www.reddit.com/api/v1/access_token"
  SEARCH_URL  = "https://oauth.reddit.com/search"
  USER_AGENT  = "openclaw-analytics/1.0 (by /u/openclaw_bot)"
  SEARCH_TERM = "OpenClaw"

  def initialize
    @client_id     = Rails.application.credentials.dig(:reddit, :client_id)     || ENV["REDDIT_CLIENT_ID"]
    @client_secret = Rails.application.credentials.dig(:reddit, :client_secret) || ENV["REDDIT_CLIENT_SECRET"]

    if @client_id.blank? || @client_secret.blank?
      raise AuthError, "Reddit credentials missing — set reddit.client_id/client_secret in credentials or REDDIT_CLIENT_ID/REDDIT_CLIENT_SECRET env vars"
    end
  end

  # Fetches and returns an array of normalized post hashes from Reddit search.
  # Always fetches a fresh token (tokens expire in 1 hour; job runs every 2 hours).
  def search_posts
    token = fetch_token
    perform_search(token)
  end

  private

  def fetch_token
    uri      = URI(TOKEN_URL)
    http     = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request  = Net::HTTP::Post.new(uri.path)
    request["User-Agent"]    = USER_AGENT
    request["Authorization"] = "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}"
    request.set_form_data("grant_type" => "client_credentials")

    response = http.request(request)
    unless response.code == "200"
      raise AuthError, "Reddit token request failed with status #{response.code}"
    end

    body  = JSON.parse(response.body)
    token = body["access_token"]
    raise AuthError, "Reddit token response missing access_token" if token.blank?

    token
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "Reddit token endpoint connection failed: #{e.message}"
  end

  def perform_search(token)
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
    request["Authorization"] = "Bearer #{token}"
    request["User-Agent"]    = USER_AGENT

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
