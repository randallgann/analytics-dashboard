require "net/http"
require "uri"
require "json"
require "time"

class HnClient
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end

  BASE_URL      = "https://hn.algolia.com/api/v1"
  SEARCH_TERM   = "OpenClaw"
  DAYS_LOOKBACK = 30

  # Searches HN Algolia API for stories mentioning SEARCH_TERM in the last DAYS_LOOKBACK days.
  # Returns an array of normalized post hashes.
  def search_stories
    uri    = URI("#{BASE_URL}/search_by_date")
    cutoff = (Time.now - DAYS_LOOKBACK * 24 * 60 * 60).to_i
    uri.query = URI.encode_www_form(
      query:          SEARCH_TERM,
      tags:           "story",
      numericFilters: "created_at_i>#{cutoff}",
      hitsPerPage:    50
    )

    response = Net::HTTP.get_response(uri)
    raise FetchError, "HN API returned #{response.code}" unless response.code == "200"

    body = JSON.parse(response.body)
    (body["hits"] || []).map { |hit| normalize(hit) }
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "HN API connection failed: #{e.message}"
  end

  private

  def normalize(hit)
    {
      external_id:   hit["objectID"],
      title:         hit["title"],
      url:           hit["url"] || "https://news.ycombinator.com/item?id=#{hit['objectID']}",
      author:        hit["author"],
      score:         hit["points"].to_i,
      comment_count: hit["num_comments"].to_i,
      subreddit:     nil,
      published_at:  hit["created_at"] ? Time.parse(hit["created_at"]) : nil
    }
  end
end
