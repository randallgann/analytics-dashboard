require "net/http"
require "uri"
require "json"
require "time"

class YoutubeClient
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end
  class AuthError < StandardError; end

  SEARCH_URL    = "https://www.googleapis.com/youtube/v3/search"
  VIDEOS_URL    = "https://www.googleapis.com/youtube/v3/videos"
  SEARCH_TERM   = "OpenClaw"
  MAX_RESULTS   = 25
  DAYS_LOOKBACK = 30

  def initialize
    @api_key = Rails.application.credentials.dig(:youtube, :api_key) || ENV["YOUTUBE_API_KEY"]
    raise AuthError, "YouTube API key is not configured" if @api_key.nil?
  end

  # Searches YouTube Data API v3 for videos mentioning SEARCH_TERM in the last DAYS_LOOKBACK days.
  # Returns an array of normalized post hashes.
  def search_videos
    raise AuthError, "YouTube API key is not configured" if @api_key.nil?

    snippets = fetch_search_results
    return [] if snippets.empty?

    video_ids = snippets.map { |s| s[:video_id] }
    stats = fetch_statistics(video_ids)

    snippets.map { |snippet| normalize(snippet, stats[snippet[:video_id]] || 0) }
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "YouTube API connection failed: #{e.message}"
  rescue URI::InvalidURIError, JSON::ParserError => e
    raise FetchError, "YouTube API response parse failed: #{e.message}"
  end

  private

  def fetch_search_results
    uri = URI(SEARCH_URL)
    uri.query = URI.encode_www_form(
      part:          "snippet",
      q:             SEARCH_TERM,
      type:          "video",
      maxResults:    MAX_RESULTS,
      order:         "date",
      publishedAfter: DAYS_LOOKBACK.days.ago.utc.iso8601,
      key:           @api_key
    )

    response = Net::HTTP.get_response(uri)

    if response.code == "403"
      body = JSON.parse(response.body)
      reason = body.dig("error", "errors", 0, "reason")
      raise AuthError, "YouTube API auth failed: #{reason}" if reason == "keyInvalid"
      raise RateLimitError, "YouTube API quota exceeded" if reason == "quotaExceeded"
      raise FetchError, "YouTube API returned 403: #{reason}"
    end

    raise FetchError, "YouTube search API returned #{response.code}" unless response.code == "200"

    body = JSON.parse(response.body)
    (body["items"] || []).map do |item|
      snippet = item["snippet"]
      {
        video_id:     item["id"]["videoId"],
        title:        snippet["title"],
        channel_name: snippet["channelTitle"],
        published_at: snippet["publishedAt"] ? Time.parse(snippet["publishedAt"]) : nil
      }
    end
  end

  def fetch_statistics(video_ids)
    uri = URI(VIDEOS_URL)
    uri.query = URI.encode_www_form(
      part: "statistics",
      id:   video_ids.join(","),
      key:  @api_key
    )

    response = Net::HTTP.get_response(uri)
    raise FetchError, "YouTube videos API returned #{response.code}" unless response.code == "200"

    body = JSON.parse(response.body)
    (body["items"] || []).each_with_object({}) do |item, hash|
      hash[item["id"]] = item.dig("statistics", "viewCount").to_i
    end
  end

  def normalize(snippet, view_count)
    video_id = snippet[:video_id]
    {
      external_id:   video_id,
      title:         snippet[:title],
      url:           "https://www.youtube.com/watch?v=#{video_id}",
      author:        snippet[:channel_name],
      score:         view_count.to_i,
      comment_count: 0,
      subreddit:     nil,
      published_at:  snippet[:published_at]
    }
  end
end
