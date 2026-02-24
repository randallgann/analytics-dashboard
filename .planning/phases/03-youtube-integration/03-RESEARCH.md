# Phase 3: YouTube Integration - Research

**Researched:** 2026-02-24
**Domain:** YouTube Data API v3 + Rails background job integration
**Confidence:** HIGH

## Summary

Phase 3 integrates YouTube video cards into the existing social feed. The SocialPost model and card
UI are already in place from Phase 2. The core work is: (1) a `YoutubeClient` service that calls the
YouTube Data API v3, (2) a `YoutubeSocialJob` background job scheduled 4 times per day, and (3) wiring
the YouTube tab into the Stimulus tabs controller and rendering view.

The YouTube Data API v3 free tier provides 10,000 units per day. A `search.list` call costs 100 units.
Four calls per day consumes 400 units (4% of quota), leaving 9,600 units headroom. The job can safely
batch each run with one `search.list` call plus one `videos.list` call for statistics (1 unit). Total:
~404 units per day — well within the free limit.

The existing `SocialPost` schema supports YouTube but needs one addition: the `subreddit` column is
Reddit-specific and YouTube needs `channel_name`. A migration adding a `channel_name` string column
reuses the same schema approach used for `subreddit` in Phase 2. Authentication requires only a Google
Cloud API key (no OAuth2) for public read-only video search.

**Primary recommendation:** Follow the HnClient/HnSocialJob pattern exactly. One new service class,
one new job, one migration for `channel_name`, minimal view and helper changes.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Net::HTTP (stdlib) | Ruby stdlib | HTTP calls to YouTube API | Already used by HnClient and RedditClient — no new dependency |
| Google Cloud API Key | N/A | Auth for public read-only YouTube search | Simpler than OAuth2; sufficient for public video data |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `google-apis-youtube_v3` gem | 0.x | Official Ruby client for YouTube API | Optional — project avoids gem dependencies where Net::HTTP suffices |
| URI / JSON (stdlib) | Ruby stdlib | URL building + response parsing | Already used by HnClient and RedditClient |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw Net::HTTP | `google-apis-youtube_v3` gem | Gem adds OAuth2 complexity + new dependency; Net::HTTP is sufficient for API key auth |
| Raw Net::HTTP | `yt` gem (nullscreen/yt) | `yt` gem is poorly maintained, doesn't support search natively |
| Single search.list call | search.list + videos.list | Two-step is needed to get `viewCount` (statistics) — search results don't include statistics |

**Installation:**
```bash
# No new gems needed — Net::HTTP, URI, and JSON are Ruby stdlib
```

## Architecture Patterns

### Recommended Project Structure

```
app/services/youtube_client.rb      # New — mirrors HnClient/RedditClient pattern
app/jobs/youtube_social_job.rb      # New — mirrors HnSocialJob/RedditSocialJob pattern
db/migrate/..._add_channel_name...  # New migration: add channel_name string to social_posts
app/models/social_post.rb           # Modified: add "youtube" to PLATFORMS, youtube? predicate
app/helpers/dashboard_helper.rb     # Modified: render_social_card handles youtube badge + channel_name
app/views/dashboard/index.html.erb  # Modified: YouTube tab added alongside HN and Reddit tabs
app/controllers/dashboard_controller.rb  # Modified: @youtube_posts, @youtube_last_updated, error var
config/recurring.yml                # Modified: youtube_social_fetch schedule (every 6 hours)
test/fixtures/social_posts.yml      # Modified: add youtube fixture
test/services/youtube_client_test.rb   # New
test/jobs/youtube_social_job_test.rb   # New
test/models/social_post_test.rb     # Modified: youtube? predicate tests
test/controllers/dashboard_controller_test.rb  # Modified: youtube tab tests
```

### Pattern 1: Two-Step YouTube Fetch (search then statistics)

**What:** `search.list` returns video IDs and basic snippet data (title, channelTitle, publishedAt).
`videos.list` returns statistics (viewCount) for a batch of IDs. Two calls per job run.

**When to use:** Always — `search.list` does NOT return `viewCount`. Statistics require `videos.list`.

**Quota math:**
- 1 `search.list` call = 100 units
- 1 `videos.list` call (batch up to 50 IDs) = 1 unit
- Total per run = 101 units
- 4 runs/day = 404 units out of 10,000 free daily units (4% usage)

**Example:**
```ruby
# Source: https://developers.google.com/youtube/v3/docs/search/list
# Step 1: search for videos
GET https://www.googleapis.com/youtube/v3/search
  ?part=snippet
  &q=OpenClaw
  &type=video
  &maxResults=25
  &order=date
  &key=YOUR_API_KEY

# Step 2: get statistics for those video IDs (batch call, costs 1 unit total)
GET https://www.googleapis.com/youtube/v3/videos
  ?part=statistics
  &id=VIDEO_ID_1,VIDEO_ID_2,...
  &key=YOUR_API_KEY
```

### Pattern 2: YoutubeClient Service Class

**What:** Plain Ruby service class using Net::HTTP. Mirrors HnClient exactly.

**Example:**
```ruby
# Source: Mirrors app/services/hn_client.rb — verified pattern from Phase 2
class YoutubeClient
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end
  class AuthError < StandardError; end

  SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"
  VIDEOS_URL = "https://www.googleapis.com/youtube/v3/videos"
  SEARCH_TERM = "OpenClaw"
  MAX_RESULTS = 25

  def initialize
    @api_key = Rails.application.credentials.dig(:youtube, :api_key) ||
               ENV.fetch("YOUTUBE_API_KEY")
  end

  def search_videos
    video_ids, snippets = fetch_search_results
    return [] if video_ids.empty?

    stats = fetch_statistics(video_ids)
    snippets.map { |s| normalize(s, stats[s[:video_id]]) }
  rescue URI::InvalidURIError, JSON::ParserError => e
    raise FetchError, "YouTube response parse error: #{e.message}"
  rescue KeyError
    raise AuthError, "YOUTUBE_API_KEY not configured"
  end

  private

  def fetch_search_results
    uri = URI(SEARCH_URL)
    uri.query = URI.encode_www_form(
      part: "snippet",
      q: SEARCH_TERM,
      type: "video",
      maxResults: MAX_RESULTS,
      order: "date",
      key: @api_key
    )

    response = Net::HTTP.get_response(uri)

    if response.code == "403"
      error_body = JSON.parse(response.body) rescue {}
      reason = error_body.dig("error", "errors", 0, "reason")
      raise AuthError, "YouTube API auth error: #{reason}" if reason == "keyInvalid"
      raise RateLimitError, "YouTube quota exceeded (403)"
    end

    raise FetchError, "YouTube search returned #{response.code}" unless response.code == "200"

    items = JSON.parse(response.body)["items"] || []
    video_ids = items.map { |i| i.dig("id", "videoId") }.compact
    snippets  = items.map { |i| extract_snippet(i) }

    [ video_ids, snippets ]
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "YouTube search connection failed: #{e.message}"
  end

  def fetch_statistics(video_ids)
    uri = URI(VIDEOS_URL)
    uri.query = URI.encode_www_form(
      part: "statistics",
      id: video_ids.join(","),
      key: @api_key
    )

    response = Net::HTTP.get_response(uri)
    raise FetchError, "YouTube videos.list returned #{response.code}" unless response.code == "200"

    items = JSON.parse(response.body)["items"] || []
    items.each_with_object({}) do |item, hash|
      hash[item["id"]] = item.dig("statistics", "viewCount").to_i
    end
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "YouTube videos.list connection failed: #{e.message}"
  end

  def extract_snippet(item)
    snippet = item["snippet"] || {}
    {
      video_id:     item.dig("id", "videoId"),
      title:        snippet["title"],
      channel_name: snippet["channelTitle"],
      published_at: snippet["publishedAt"] ? Time.parse(snippet["publishedAt"]) : nil
    }
  end

  def normalize(snippet, view_count)
    {
      external_id:  snippet[:video_id],
      title:        snippet[:title],
      url:          "https://www.youtube.com/watch?v=#{snippet[:video_id]}",
      author:       snippet[:channel_name],   # mapped to author — displayed as channel
      channel_name: snippet[:channel_name],   # also stored in channel_name column
      score:        view_count.to_i,          # view count stored as score for ranking
      comment_count: 0,                       # not fetched — would cost extra quota
      published_at: snippet[:published_at]
    }
  end
end
```

### Pattern 3: YoutubeSocialJob

**What:** Mirrors HnSocialJob/RedditSocialJob. Calls client, upserts results, manages error cache key.

**Example:**
```ruby
# Source: Mirrors app/jobs/hn_social_job.rb — verified pattern from Phase 2
class YoutubeSocialJob < ApplicationJob
  queue_as :default

  FETCH_ERROR_KEY = "social_fetch_error:youtube"

  def perform
    client = YoutubeClient.new
    posts  = client.search_videos
    now    = Time.current

    count = 0
    posts.each do |post|
      attrs = post.merge(
        platform:   "youtube",
        fetched_at: now,
        created_at: now,
        updated_at: now
      )
      SocialPost.upsert(attrs, unique_by: [:platform, :external_id])
      count += 1
    end

    Rails.cache.delete(FETCH_ERROR_KEY)
    Rails.logger.info "YoutubeSocialJob: upserted #{count} YouTube videos"
  rescue YoutubeClient::AuthError => e
    Rails.logger.error "YoutubeSocialJob: auth error — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, "API key not configured", expires_in: 6.hours)
    # Do not re-raise — missing credentials is expected pre-deployment
  rescue YoutubeClient::FetchError => e
    Rails.logger.error "YoutubeSocialJob: fetch failed — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)
  rescue YoutubeClient::RateLimitError => e
    Rails.logger.warn "YoutubeSocialJob: quota exceeded — #{e.message}"
    Rails.cache.write(FETCH_ERROR_KEY, "Quota exceeded", expires_in: 6.hours)
  rescue StandardError => e
    Rails.logger.error "YoutubeSocialJob: unexpected error — #{e.class}: #{e.message}"
    raise
  end
end
```

### Pattern 4: Recurring Schedule (6 hours = 4x per day)

**What:** `config/recurring.yml` entry for `YoutubeSocialJob` at 6-hour intervals.

**Example:**
```yaml
# config/recurring.yml
youtube_social_fetch:
  class: YoutubeSocialJob
  schedule: every 6 hours
  queue: default
```

"Every 6 hours" = 4 times per day maximum. This is the exact constraint from YT-04.

### Pattern 5: SocialPost Model Extension

**What:** Add "youtube" to PLATFORMS constant, add `youtube?` predicate, no new fields required
beyond `channel_name` migration.

**Example:**
```ruby
# app/models/social_post.rb — modified
PLATFORMS = %w[hn reddit youtube].freeze

def youtube?
  platform == "youtube"
end
```

### Pattern 6: render_social_card Helper Extension

**What:** Add YouTube badge letter ("Y" but YouTube red, distinct from HN's orange "Y").
Add channel_name display in meta row (analogous to subreddit for Reddit).
Map `score` to "views" label for YouTube cards.

**Example:**
```ruby
# app/helpers/dashboard_helper.rb — modified render_social_card
badge = content_tag(:div, class: "dash-social-badge dash-social-badge--#{post.platform}") do
  if post.hn?
    "Y".html_safe
  elsif post.reddit?
    "R".html_safe
  else
    "YT".html_safe   # YouTube badge
  end
end

# In meta_parts, for YouTube:
meta_parts << content_tag(:span, "#{format_number(post.score)} views") if post.youtube?
meta_parts << content_tag(:span, post.score > 0 ? "#{format_number(post.score)} pts" : nil) unless post.youtube?
meta_parts << content_tag(:span, post.channel_name) if post.youtube? && post.channel_name.present?
meta_parts << content_tag(:span, "r/#{post.subreddit}") if post.reddit? && post.subreddit.present?
```

**CSS addition needed** (`dash-social-badge--youtube`):
```css
.dash-social-badge--youtube {
  background: #ff0000;
  color: #fff;
}
```

### Pattern 7: View Tab Addition

**What:** Add YouTube tab button and panel to Stimulus tabs controller section.

**Example:**
```erb
<%# In index.html.erb — add to tab nav %>
<button data-tabs-target="btn" data-tab-id="youtube" data-action="click->tabs#select" class="dash-tab-btn">YouTube</button>

<%# YouTube Tab panel — mirrors HN and Reddit panels %>
<div data-tabs-target="tab" data-tab-id="youtube" hidden>
  <div class="dash-tab-updated">
    <% if @youtube_last_updated %>
      Last updated <%= time_ago_in_words(@youtube_last_updated) %> ago
    <% end %>
  </div>
  <% if @youtube_fetch_error.present? %>
    <div class="dash-social-error">Unable to fetch YouTube videos</div>
  <% elsif @youtube_posts.empty? %>
    <div class="dash-social-empty">No recent mentions found on YouTube</div>
  <% else %>
    <% @youtube_posts.each do |post| %>
      <%= render_social_card(post) %>
    <% end %>
  <% end %>
</div>
```

### Anti-Patterns to Avoid

- **Fetching comment_count from YouTube:** Would require a third API call (commentThreads.list, 1 unit each per video). Unnecessary for the dashboard — use 0 as default.
- **Caching the API key in the service class constant:** API keys loaded at class definition time (not instance) can fail to initialize when credentials aren't loaded. Load in `initialize` like GithubClient does.
- **Using search.list with `order: "viewCount"`:** Returns old viral videos, not recent mentions. Use `order: "date"` to surface fresh content.
- **Storing view count in comment_count column:** Semantically wrong. Store in `score` column — it's already used for HN points and Reddit upvotes (engagement signal). The helper renders it as "views" for YouTube.
- **Paginating search results:** Each page = 100 units. One page of 25 results is sufficient and keeps quota usage flat.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retries with backoff | Custom retry logic | Faraday-retry (already in Gemfile) or simple rescue + single retry | YouTube 403 on quota exceeded should NOT be retried — back off until next scheduled run |
| YouTube URL construction | Custom URL builder | Hardcode `https://www.youtube.com/watch?v=#{video_id}` | YouTube video URLs are stable and trivial to construct from video ID |
| View count formatting | Custom number formatter | Existing `format_number` helper | Already handles nil + comma formatting |
| Time formatting | Custom date formatter | Existing `time_ago_in_words` + `format_date` helpers | Already in DashboardHelper |
| Quota tracking | Custom counter/database table | Schedule constraint (6-hour interval = max 4 runs) | SolidQueue schedule guarantees max frequency; no runtime tracking needed |

**Key insight:** YouTube quota is managed entirely through scheduling, not runtime logic. The job runs at most 4 times per day by design. No quota counter or guard clause needed in the job itself.

## Common Pitfalls

### Pitfall 1: 403 Response Means Both Quota Exhausted AND Invalid API Key
**What goes wrong:** YouTube returns HTTP 403 for both "quota exceeded" and "invalid API key". Code that only checks for 403 can't distinguish the cause.
**Why it happens:** Google uses 403 for multiple distinct error conditions.
**How to avoid:** Parse the response body's `error.errors[0].reason` field. `"quotaExceeded"` means quota. `"keyInvalid"` means bad credentials.
**Warning signs:** Job silently logs "quota exceeded" when credentials were never configured.

```ruby
# Response body example:
# { "error": { "errors": [{ "reason": "quotaExceeded" }] } }
# { "error": { "errors": [{ "reason": "keyInvalid" }] } }
```

### Pitfall 2: search.list Does Not Return View Counts
**What goes wrong:** Developer assumes the search result snippet includes statistics. It does not. `viewCount` is only in the `statistics` part, which is only available from `videos.list`.
**Why it happens:** The API has two resource types — search results and video resources — with different available fields.
**How to avoid:** Always make the two-step call: search.list for IDs, videos.list for statistics.
**Warning signs:** All YouTube cards show 0 views.

### Pitfall 3: SocialPost PLATFORMS Validation Rejects "youtube"
**What goes wrong:** Job upserts work but model validation fails silently or raises in tests.
**Why it happens:** `PLATFORMS = %w[hn reddit].freeze` — "youtube" is not in the list.
**How to avoid:** Add "youtube" to PLATFORMS before writing the job. Test the model first.
**Warning signs:** `SocialPost.upsert` succeeds (bypasses validations) but `SocialPost.new(platform: "youtube").valid?` returns false.

### Pitfall 4: Quota Resets at Midnight Pacific Time, Not UTC
**What goes wrong:** Developer assumes quota resets at midnight UTC and schedules jobs accordingly.
**Why it happens:** Google resets YouTube API quotas at midnight Pacific Time (PT), not UTC.
**How to avoid:** Use "every 6 hours" in recurring.yml — this is time-zone agnostic and guarantees exactly 4 runs per day regardless of time zone alignment.
**Warning signs:** Quota exhaustion in the last hours of the day because runs were bunched together.

### Pitfall 5: channel_name Column Not in social_posts Schema
**What goes wrong:** YoutubeClient normalize returns `channel_name:` key but SocialPost upsert fails or silently drops it.
**Why it happens:** The original migration only has `subreddit` as a platform-specific column. No `channel_name` column exists.
**How to avoid:** Add migration `add_column :social_posts, :channel_name, :string` before writing the job. Alternatively, store channel in `author` column only (no migration needed, but loses the explicit column).
**Warning signs:** channel_name always nil in dashboard.

**Resolution:** The project uses `author` field for attribution already. Store channel_name in BOTH `author` (for the existing card meta row) AND a new `channel_name` column (for explicit YouTube display). OR — simpler — store only in `author` since it maps semantically and the helper already renders `post.author`. The `author` column is the correct semantic fit; a separate `channel_name` column adds complexity without benefit.

**Recommended approach:** Map `channel_name` to `author` in normalize. No migration needed. The helper already renders `post.author`. Add `channel_name` as a helper-level label ("Channel: #{post.author}") for YouTube cards only.

### Pitfall 6: AuthError Silencing vs. Raising
**What goes wrong:** Missing API key causes job to raise `KeyError` (from `ENV.fetch`) at the top of the job, which re-raises as unexpected error and triggers Solid Queue retry.
**Why it happens:** `ENV.fetch("YOUTUBE_API_KEY")` raises `KeyError` if absent, unlike `ENV["YOUTUBE_API_KEY"]` which returns nil.
**How to avoid:** Follow the pattern from Phase 2 (RedditSocialJob) — silence AuthError as expected pre-deployment. Either use `ENV["YOUTUBE_API_KEY"]` and handle nil explicitly, or rescue `KeyError` in the job.
**Warning signs:** Job fails immediately in development/test with `KeyError: key not found: YOUTUBE_API_KEY`.

## Code Examples

Verified patterns from official sources:

### YouTube search.list Request URL
```
# Source: https://developers.google.com/youtube/v3/docs/search/list
GET https://www.googleapis.com/youtube/v3/search
  ?part=snippet
  &q=OpenClaw
  &type=video
  &maxResults=25
  &order=date
  &key=YOUR_API_KEY
```

### YouTube videos.list Request URL (batch statistics)
```
# Source: https://developers.google.com/youtube/v3/docs/videos/list
GET https://www.googleapis.com/youtube/v3/videos
  ?part=statistics
  &id=VIDEO_ID_1,VIDEO_ID_2,VIDEO_ID_3
  &key=YOUR_API_KEY
```

### search.list Response Shape (relevant fields)
```json
{
  "items": [
    {
      "id": { "videoId": "abc123def" },
      "snippet": {
        "title": "OpenClaw Tutorial",
        "channelTitle": "DevChannel",
        "publishedAt": "2026-02-20T10:00:00Z",
        "description": "..."
      }
    }
  ]
}
```

### videos.list Response Shape (relevant fields)
```json
{
  "items": [
    {
      "id": "abc123def",
      "statistics": {
        "viewCount": "14523",
        "likeCount": "312",
        "commentCount": "45"
      }
    }
  ]
}
```

### Credential Access Pattern (matches GithubClient)
```ruby
# Source: app/services/github_client.rb — verified in Phase 1
api_key = Rails.application.credentials.dig(:youtube, :api_key) ||
          ENV["YOUTUBE_API_KEY"]
```

### Rails Credentials Structure
```yaml
# config/credentials.yml.enc (via rails credentials:edit)
youtube:
  api_key: AIza...
```

### Test Double Pattern (matches RedditSocialJob tests)
```ruby
# Source: test/jobs/reddit_social_job_test.rb — verified Phase 2 pattern
def with_mock_youtube_client(videos: SAMPLE_VIDEOS)
  fake = YoutubeClient.allocate
  fake.define_singleton_method(:search_videos) { videos }
  YoutubeClient.define_singleton_method(:new) { fake }
  yield fake
ensure
  YoutubeClient.singleton_class.remove_method(:new)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| YouTube API v2 | YouTube Data API v3 | 2015 (v2 deprecated) | Must use v3 only |
| OAuth2 required for all reads | API key sufficient for public data | v3 launch | Simpler auth for read-only dashboard use case |
| `google-api-client` monolith gem | `google-apis-youtube_v3` individual gem | 2021 | Smaller dependency; but Net::HTTP is simpler still |

**Deprecated/outdated:**
- YouTube API v2: Shut down in 2015. All documentation references must be v3.
- `youtube_it` gem: Deprecated, targets v2. Do not use.
- `yt` gem: Poorly maintained; no search support. Do not use.

## Open Questions

1. **view_count as score — ranking implications**
   - What we know: Phase 4 will introduce recency-weighted engagement ranking across all platforms. HN uses points, Reddit uses upvotes, YouTube would use view_count stored in `score`.
   - What's unclear: View counts are orders of magnitude larger than HN points (14,000 views vs 150 points). Cross-platform ranking in Phase 4 may need per-platform normalization.
   - Recommendation: Store view_count in `score` as-is. Phase 4 ranking is out of scope here. Document the scale discrepancy for Phase 4 planner.

2. **YouTube quota — confirmed still 10,000 units/day?**
   - What we know: As of research date (2026-02-24), multiple sources confirm 10,000 units/day free. STATE.md flags this as a concern to verify.
   - What's unclear: Google has not announced changes, but quota policies can change.
   - Recommendation: Proceed with 4x/day schedule (404 units/day). Check Google Cloud Console quota dashboard on first deployment to confirm.

3. **`publishedAfter` filter — should we limit to recent videos?**
   - What we know: `search.list` supports `publishedAfter` (RFC 3339 format) to filter by date. Without it, results may include old videos.
   - What's unclear: Whether `order=date` alone is sufficient to surface recent content, or if a 30-day `publishedAfter` filter is needed.
   - Recommendation: Add `publishedAfter` set to 30 days ago (matching the DataRetentionJob pruning window). This ensures fetched videos align with what the retention job keeps.

## Sources

### Primary (HIGH confidence)
- [YouTube Data API - search.list](https://developers.google.com/youtube/v3/docs/search/list) — quota cost (100 units), parameters (q, part, type, maxResults, order, publishedAfter), response shape
- [YouTube Data API - videos.list](https://developers.google.com/youtube/v3/docs/videos/list) — quota cost (1 unit), statistics part (viewCount)
- [YouTube Data API Overview](https://developers.google.com/youtube/v3/getting-started) — free tier 10,000 units/day, API key vs OAuth2 guidance
- [YouTube Data API - Sample Requests](https://developers.google.com/youtube/v3/sample_requests) — base URL `https://www.googleapis.com/youtube/v3/`
- Phase 2 codebase — HnClient, RedditClient, HnSocialJob, RedditSocialJob, SocialPost model, DashboardHelper, tabs_controller.js — all direct reads, HIGH confidence

### Secondary (MEDIUM confidence)
- [YouTube Quota Calculator](https://developers.google.com/youtube/v3/determine_quota_cost) — confirmed search.list = 100 units, videos.list = 1 unit

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Net::HTTP pattern directly verified in codebase; API endpoints confirmed via official docs
- Architecture: HIGH — Mirrors Phase 2 patterns exactly; no new patterns introduced
- Pitfalls: HIGH — PLATFORMS validation and auth error patterns verified directly in source; quota math verified via official docs
- Quota math: HIGH — 100 units/search.list confirmed via official docs; 10,000/day free tier confirmed

**Research date:** 2026-02-24
**Valid until:** 2026-03-26 (30 days — YouTube API v3 quota policies are stable)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| YT-01 | Dashboard displays recent YouTube videos mentioning OpenClaw as card feed | Two-step fetch pattern (search.list + videos.list) delivers videos; existing card feed infrastructure in place from Phase 2 |
| YT-02 | Each YouTube card shows title, view count, channel name, and published date | search.list snippet provides title, channelTitle, publishedAt; videos.list statistics provides viewCount; render_social_card helper extended for YouTube |
| YT-03 | Each YouTube card links to original YouTube video | URL constructed as `https://www.youtube.com/watch?v={videoId}` from search result id.videoId |
| YT-04 | Background job fetches YouTube videos via Data API v3 (max 4x/day to respect quota) | "every 6 hours" in recurring.yml = exactly 4 runs/day; 404 units/day = 4% of 10,000 free quota |
</phase_requirements>
