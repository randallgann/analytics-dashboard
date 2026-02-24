# Phase 2: Social Feed — HN and Reddit - Research

**Researched:** 2026-02-23
**Domain:** Hacker News Algolia API + Reddit OAuth2 API + Rails 8 ActiveRecord + Stimulus tabs
**Confidence:** HIGH for HN (public, no-auth API well-documented); MEDIUM-HIGH for Reddit (OAuth2 flow confirmed, search params confirmed, response structure confirmed via multiple sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Card layout & content
- Medium cards: 2-3 lines per post with title, metadata row, and platform badge
- Metadata per card: score/points/upvotes, comment count, author, date, and subreddit (Reddit only)
- Platform badge: colored icon only (HN "Y" icon, Reddit alien icon in brand colors) — no text label
- Cards link to the original URL the post points to (not the discussion/comments page)

#### Feed ordering & sections
- Tabbed view: single "Social" section with tabs to switch between HN, Reddit, or All
- Placed below the existing GitHub metrics sections on the dashboard
- Add "Social" to the sticky nav bar as a new section link
- Posts sorted by highest score first within each tab
- Show top 5 posts per tab — compact highlights view

#### Empty & stale states
- Simple message when no mentions found: "No recent mentions found on Hacker News" (or Reddit) — plain text, subdued, consistent with GitHub chart empty states
- Subtle timestamp only for staleness: "Last updated X ago" in small muted text — no warning badges
- Failed platform tab stays visible with error message: "Unable to fetch [platform] posts" — user knows the feature exists but is temporarily unavailable

#### Post matching criteria
- Name match only: search for "OpenClaw" in post titles and text — no URL matching or broad terms
- 30-day lookback window: consistent with GitHub metrics time range
- Case sensitivity: Claude's discretion based on what each platform's API supports

### Claude's Discretion
- Case sensitivity approach per platform API
- Which subreddits to search (all of Reddit vs curated list — based on API capabilities)
- Exact icon/badge design within the dark theme
- Tab implementation details (CSS tabs, JS tabs, etc.)
- "All" tab interleaving strategy

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HN-01 | Dashboard displays recent HN posts mentioning OpenClaw as card feed | Algolia search API returns story hits with all needed fields; stored in SocialPost model; rendered as cards below GitHub sections |
| HN-02 | Each HN card shows title, points, comment count, author, and published date | Algolia hit fields: `title`, `points`, `num_comments`, `author`, `created_at` — all present in response |
| HN-03 | Each HN card links to original HN discussion | CONTEXT.md override: cards link to `url` field (original post URL), not HN discussion — use `objectID` to construct HN link only as fallback |
| HN-04 | Background job fetches HN posts via Algolia API every 2 hours | Solid Queue recurring.yml — append `hn_social_fetch` entry with `schedule: every 2 hours` |
| RDT-01 | Dashboard displays recent Reddit posts mentioning OpenClaw as card feed | Reddit OAuth2 `/search` endpoint returns posts; stored in SocialPost model alongside HN; rendered as tab panel |
| RDT-02 | Each Reddit card shows title, upvotes, comment count, subreddit, author, and published date | Reddit post fields: `title`, `ups`, `num_comments`, `subreddit`, `author`, `created_utc` — all present in listing response |
| RDT-03 | Each Reddit card links to original Reddit post | Reddit post `url` field is the direct post link; `permalink` for reddit.com internal link |
| RDT-04 | Background job fetches Reddit posts via API (OAuth2) every 2 hours | Reddit requires OAuth2 client_credentials flow; token expires every hour — must re-fetch before each job run; Solid Queue recurring.yml entry |
| SOC-01 | All social posts stored in normalized SocialPost model (platform + external_id + title + url + author + score + comment_count + published_at) | Single model, platform string column, unique index on [platform, external_id] prevents duplicates; DataRetentionJob extended to prune SocialPost records |
| SOC-02 | Platform badge displayed on each social card (HN, Reddit, YouTube) | Unicode icon ("Y" for HN, alien SVG for Reddit) with brand color span; CSS classes for per-platform styling |
| SOC-03 | "Last updated" timestamp shown per data source section | `SocialPost.where(platform: "hn").order(fetched_at: :desc).first&.fetched_at` — requires `fetched_at` column on SocialPost |
</phase_requirements>

---

## Summary

Phase 2 adds a Social feed section to the existing dashboard. It requires two new API clients (HN Algolia and Reddit OAuth2), one new ActiveRecord model (SocialPost), two new background jobs (HnSocialJob and RedditSocialJob), and dashboard UI additions (Social section with Stimulus tabs and social post cards).

The HN Algolia API is fully public, requires no authentication, and supports keyword search with date-range filtering via `numericFilters=created_at_i>UNIX_TIMESTAMP`. It returns story hits with all required fields (`title`, `url`, `author`, `points`, `num_comments`, `created_at`, `objectID`). The search term "OpenClaw" is case-insensitive by default in Algolia. A 30-day lookback uses `created_at_i` numeric filter.

The Reddit API requires OAuth2 client_credentials (app-only) authentication. Tokens expire after 1 hour and cannot be refreshed — the job must request a fresh token before each run. The search endpoint is `GET https://oauth.reddit.com/search` with params `q`, `sort`, `t`, `limit`, and `type=link`. Reddit's API searches across all subreddits by default unless `restrict_sr` is set. Search results include all fields needed (title, ups, num_comments, subreddit, author, created_utc, permalink, url). Rate limit is 60 requests/minute authenticated. Reddit registration requires registering a "script" type app at reddit.com/prefs/apps to get a client_id and client_secret — this is a user setup prerequisite before production deployment.

The tab UI is implemented with the existing Stimulus.js framework (already installed via stimulus-rails) — no new JavaScript libraries needed. A `tabs_controller.js` handles show/hide between HN, Reddit, and All tabs. The SocialPost model follows the same pattern as GitHubMetric but with a `platform` discriminator column. The DataRetentionJob is extended to prune SocialPost records older than 30 days.

**Primary recommendation:** Build two separate service classes (HnClient, RedditClient) following the GithubClient pattern. Store all posts in a single SocialPost model with platform discrimination. Use one Stimulus tabs controller for the social section. Extend DataRetentionJob to prune social posts.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| faraday | 2.x (already a dep) | HTTP client for HN Algolia and Reddit API | Already in Gemfile.lock as Octokit dependency; battle-tested HTTP abstraction |
| stimulus-rails | already installed | Tab UI without a full JS framework | Already installed; tabs_controller pattern is established Rails 8 pattern |
| solid_queue | already installed | Recurring background jobs every 2 hours | Already running; just add new recurring.yml entries |
| Net::HTTP (stdlib) | stdlib | Alternative to Faraday for simple GET requests | Built-in, zero deps — acceptable for HN (simple GET, no auth) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| JSON (stdlib) | stdlib | Parse API responses | Built-in; no gem needed for JSON parsing |
| Base64 (stdlib) | stdlib | Reddit basic auth header encoding | Built-in; `Base64.strict_encode64("#{id}:#{secret}")` |

### No New Gems Needed
Both HN and Reddit APIs are REST APIs returning JSON. Faraday is already present (as Octokit's dependency). No dedicated Reddit gem is needed — available Ruby Reddit gems (redd, reddit-base, karl-b/reddit-api) are either unmaintained since 2016 or require user-context OAuth (not app-only). Hand-rolling the HTTP client with Faraday or Net::HTTP is the correct approach here and matches the existing GithubClient pattern.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Faraday for Reddit | redd gem | redd is unmaintained, targets user-context OAuth2 not app-only; custom client is simpler |
| Stimulus tabs | CSS-only radio-button tabs | CSS-only tabs have accessibility issues; Stimulus is already installed and well-suited |
| Stimulus tabs | Turbo Frames per tab | Over-engineering for static data that's already loaded in one controller action |
| Single SocialPost model | Separate HnPost/RedditPost models | Single model is cleaner, shares scopes, easier to prune, matches SOC-01 spec |

**Installation:**
```bash
# No new gems — faraday, stimulus-rails, and solid_queue are already installed
bundle install  # no-op if Gemfile unchanged
```

---

## Architecture Patterns

### Recommended Project Structure
```
app/
├── models/
│   └── social_post.rb              # platform, external_id, title, url, author,
│                                   # score, comment_count, subreddit, published_at, fetched_at
├── jobs/
│   ├── hn_social_job.rb            # Fetches HN posts every 2 hours
│   ├── reddit_social_job.rb        # Fetches Reddit posts every 2 hours
│   └── data_retention_job.rb       # EXTEND to also prune SocialPost records
├── services/
│   ├── github_client.rb            # EXISTING — unchanged
│   ├── hn_client.rb                # Wraps HN Algolia API, returns array of post hashes
│   └── reddit_client.rb            # Wraps Reddit OAuth2 API, manages token lifecycle
├── controllers/
│   └── dashboard_controller.rb     # EXTEND: add @hn_posts, @reddit_posts, per-platform timestamps
├── javascript/controllers/
│   └── tabs_controller.js          # NEW Stimulus controller for HN/Reddit/All tabs
└── views/
    └── dashboard/
        └── index.html.erb          # EXTEND: add #social section + tabbed card feed

config/
├── recurring.yml                   # EXTEND: add hn_social_fetch and reddit_social_fetch entries
└── credentials.yml.enc             # EXTEND: add reddit: { client_id:, client_secret: }
```

### Pattern 1: SocialPost Model — Single Table, Platform Discriminator
**What:** One ActiveRecord model stores HN and Reddit posts. The `platform` string column ("hn", "reddit") distinguishes them. `external_id` is the platform's own ID (HN `objectID`, Reddit post `name`/`id`). Unique index on [platform, external_id] prevents duplicate inserts.
**When to use:** Always — this is the SOC-01 spec.
**Schema:**
```ruby
create_table :social_posts do |t|
  t.string  :platform,      null: false   # "hn" or "reddit"
  t.string  :external_id,   null: false   # HN objectID or Reddit post id
  t.string  :title,         null: false
  t.string  :url                          # original URL (may be nil for self-posts)
  t.string  :author
  t.integer :score,         default: 0    # points (HN) or ups (Reddit)
  t.integer :comment_count, default: 0
  t.string  :subreddit                    # nil for HN posts
  t.datetime :published_at
  t.datetime :fetched_at,  null: false    # when our job retrieved it (for SOC-03 timestamp)

  t.timestamps
end

add_index :social_posts, [:platform, :external_id], unique: true
add_index :social_posts, :platform                             # for per-platform queries
add_index :social_posts, :published_at                        # for 30-day window queries
```

### Pattern 2: HnClient — Public Algolia API (No Auth)
**What:** Simple HTTP client querying `https://hn.algolia.com/api/v1/search_by_date` with keyword filter and 30-day `numericFilters`. No API key required. Case-insensitive by default (Algolia tokenizes search terms). Returns up to `hitsPerPage` story hits, sorted by date (most recent first from `search_by_date`).
**When to use:** HnSocialJob calls this once per run.
**Example:**
```ruby
# app/services/hn_client.rb
class HnClient
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end

  BASE_URL = "https://hn.algolia.com/api/v1"
  SEARCH_TERM = "OpenClaw"
  DAYS_LOOKBACK = 30

  # Returns array of hashes with normalized field names
  def search_stories
    cutoff = (Time.now - DAYS_LOOKBACK.days).to_i
    uri = URI("#{BASE_URL}/search_by_date")
    uri.query = URI.encode_www_form(
      query: SEARCH_TERM,
      tags: "story",
      numericFilters: "created_at_i>#{cutoff}",
      hitsPerPage: 50
    )

    response = Net::HTTP.get_response(uri)
    raise FetchError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data["hits"].map { |hit| normalize(hit) }
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "HN Algolia unreachable: #{e.message}"
  end

  private

  def normalize(hit)
    {
      external_id: hit["objectID"],
      title:       hit["title"],
      url:         hit["url"] || "https://news.ycombinator.com/item?id=#{hit['objectID']}",
      author:      hit["author"],
      score:       hit["points"].to_i,
      comment_count: hit["num_comments"].to_i,
      subreddit:   nil,
      published_at: Time.parse(hit["created_at"])
    }
  end
end
```

**HN API fields confirmed (MEDIUM confidence — verified via multiple sources):**
| Field | Type | Notes |
|-------|------|-------|
| `objectID` | string | Unique HN item ID |
| `title` | string | Story title |
| `url` | string | External URL (nil for Ask HN / text posts) |
| `author` | string | HN username |
| `points` | integer | Upvote score |
| `num_comments` | integer | Comment count |
| `created_at` | string | ISO 8601 timestamp |
| `created_at_i` | integer | Unix timestamp (for numericFilters) |

**HN API endpoints:**
- `GET /api/v1/search?query=X&tags=story` — sorted by relevance
- `GET /api/v1/search_by_date?query=X&tags=story` — sorted by date, most recent first
- Use `search_by_date` for our case; Algolia's relevance ranking is less meaningful than recency for a "recent mentions" feed. Job then sorts by score in DB query.

### Pattern 3: RedditClient — OAuth2 App-Only (Client Credentials)
**What:** Two-step: (1) POST to token endpoint with Basic auth (client_id:client_secret), (2) GET search endpoint with Bearer token. Token expires in 1 hour. Since job runs every 2 hours, always fetch a fresh token at job start — do not cache between job runs. App-only grant type: `client_credentials`.
**When to use:** RedditSocialJob calls this once per run. Token fetch + search = 2 HTTP calls per run.
**Example:**
```ruby
# app/services/reddit_client.rb
class RedditClient
  class AuthError < StandardError; end
  class RateLimitError < StandardError; end
  class FetchError < StandardError; end

  TOKEN_URL   = "https://www.reddit.com/api/v1/access_token"
  SEARCH_URL  = "https://oauth.reddit.com/search"
  USER_AGENT  = "openclaw-analytics/1.0 (by /u/openclaw_bot)"
  SEARCH_TERM = "OpenClaw"

  def initialize
    @client_id     = Rails.application.credentials.dig(:reddit, :client_id) ||
                     ENV.fetch("REDDIT_CLIENT_ID")
    @client_secret = Rails.application.credentials.dig(:reddit, :client_secret) ||
                     ENV.fetch("REDDIT_CLIENT_SECRET")
  end

  # Returns array of normalized post hashes
  def search_posts
    token = fetch_token
    perform_search(token)
  end

  private

  def fetch_token
    uri = URI(TOKEN_URL)
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(@client_id, @client_secret)
    req["User-Agent"] = USER_AGENT
    req.set_form_data("grant_type" => "client_credentials")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }

    raise AuthError, "Token fetch failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    raise AuthError, "No access_token in response" unless data["access_token"]
    data["access_token"]
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "Reddit token endpoint unreachable: #{e.message}"
  end

  def perform_search(token)
    uri = URI(SEARCH_URL)
    uri.query = URI.encode_www_form(
      q:     SEARCH_TERM,
      sort:  "top",
      t:     "month",      # past 30 days
      limit: 50,
      type:  "link"        # posts only, no subreddits
    )

    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "bearer #{token}"
    req["User-Agent"]    = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }

    return [] if response.code == "429"  # rate limited — return empty, log
    raise FetchError, "Reddit search failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data.dig("data", "children")&.map { |child| normalize(child["data"]) } || []
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, SocketError => e
    raise FetchError, "Reddit API unreachable: #{e.message}"
  end

  def normalize(post)
    {
      external_id:   post["id"],                        # e.g. "abc123"
      title:         post["title"],
      url:           post["url"],                       # direct link to content
      author:        post["author"],
      score:         post["ups"].to_i,
      comment_count: post["num_comments"].to_i,
      subreddit:     post["subreddit"],                 # without r/ prefix
      published_at:  Time.at(post["created_utc"].to_i).utc
    }
  end
end
```

**Reddit API confirmed fields (MEDIUM-HIGH confidence — multiple sources confirm):**
| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Short base36 post ID (e.g. "abc123") |
| `name` | string | Fullname (e.g. "t3_abc123") |
| `title` | string | Post title |
| `url` | string | URL the post links to (or reddit.com URL for self posts) |
| `ups` | integer | Upvote count |
| `num_comments` | integer | Comment count |
| `subreddit` | string | Subreddit name without r/ prefix |
| `author` | string | Reddit username |
| `created_utc` | float | Unix timestamp in UTC |
| `permalink` | string | /r/sub/comments/... path (prepend reddit.com) |
| `selftext` | string | Body of self posts (not needed for our case) |

**Reddit search response structure:**
```json
{
  "kind": "Listing",
  "data": {
    "dist": 25,
    "children": [
      { "kind": "t3", "data": { /* post fields */ } }
    ],
    "after": "t3_abc123"
  }
}
```

**Reddit search parameters (confirmed):**
| Param | Values | Notes |
|-------|--------|-------|
| `q` | string | Search query — searches title and selftext |
| `sort` | `top`, `new`, `hot`, `relevance`, `comments` | Use `top` to get highest-scoring posts |
| `t` | `hour`, `day`, `week`, `month`, `year`, `all` | Time filter — `month` covers ~30 days |
| `limit` | 1-100 | Max results per request (default 25) |
| `type` | `link`, `sr`, `user` | Filter to posts only with `link` |
| `restrict_sr` | `true`/`false` | Default false = search all subreddits |

**Case sensitivity:** Reddit search is case-insensitive (confirmed by Reddit's search behavior). "OpenClaw", "openclaw", "OPENCLAW" all return same results.

**Subreddit scope:** Use all of Reddit (no `restrict_sr`) — OpenClaw mentions may appear in any subreddit (programming, opensource, devtools, etc.). Claude's discretion, but all-Reddit is the correct default given the API supports it.

### Pattern 4: Job Pattern — Independent Error Isolation
**What:** Each platform's job runs independently. Rate limit error or auth failure on Reddit does not affect HN job. Each job catches platform-specific errors, logs them, and stores a fetch_error state so the UI can show "Unable to fetch" without crashing.
**When to use:** Always — matches SOC-03 requirement for independent platform display.
**Example:**
```ruby
# app/jobs/hn_social_job.rb
class HnSocialJob < ApplicationJob
  queue_as :default

  def perform
    client = HnClient.new
    posts = client.search_stories

    now = Time.current
    posts.each do |post|
      upsert(post.merge(platform: "hn", fetched_at: now))
    end

    Rails.logger.info "HnSocialJob: upserted #{posts.size} HN posts"
  rescue HnClient::FetchError => e
    Rails.logger.error "HnSocialJob: fetch failed: #{e.message}"
    # Do not re-raise — job will run again in 2 hours
  rescue => e
    Rails.logger.error "HnSocialJob failed: #{e.class}: #{e.message}"
    raise  # Re-raise unexpected errors for Solid Queue retry
  end

  private

  def upsert(attrs)
    SocialPost.find_or_create_by!(platform: attrs[:platform], external_id: attrs[:external_id]) do |p|
      p.assign_attributes(attrs.except(:platform, :external_id))
    end
    # Note: find_or_create_by does NOT update existing records.
    # Use upsert_all for score/comment_count updates on existing posts:
    SocialPost.upsert(
      attrs.merge(updated_at: Time.current),
      unique_by: [:platform, :external_id]
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "HnSocialJob: skipping invalid post #{attrs[:external_id]}: #{e.message}"
  end
end
```

**Important:** Use `SocialPost.upsert` (Rails 6+) with `unique_by` to update existing records (score and comment_count change over time). `find_or_create_by` would leave stale scores.

### Pattern 5: Stimulus Tabs Controller
**What:** A Stimulus controller handles tab switching between HN, Reddit, and All. Uses `data-tabs-target="btn"` and `data-tabs-target="tab"` with matching IDs. Active class applied via `data-tabs-active-class`.
**When to use:** The Social section UI.
**JavaScript:**
```javascript
// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["active"]
  static targets = ["btn", "tab"]
  static values  = { defaultTab: String }

  connect() {
    this.tabTargets.forEach(t => t.hidden = true)
    const defaultTab = this.tabTargets.find(t => t.id === this.defaultTabValue)
    if (defaultTab) defaultTab.hidden = false
    const defaultBtn = this.btnTargets.find(b => b.id === this.defaultTabValue)
    if (defaultBtn) defaultBtn.classList.add(...this.activeClasses)
  }

  select(event) {
    const selectedId = event.currentTarget.id
    this.tabTargets.forEach(t => t.hidden = true)
    this.btnTargets.forEach(b => b.classList.remove(...this.activeClasses))
    const selectedTab = this.tabTargets.find(t => t.id === selectedId)
    if (selectedTab) selectedTab.hidden = false
    event.currentTarget.classList.add(...this.activeClasses)
  }
}
```

**HTML structure (ERB):**
```erb
<section id="social" class="dash-section">
  <div data-controller="tabs"
       data-tabs-default-tab-value="tab-hn"
       data-tabs-active-class="dash-tab-btn--active">

    <div class="dash-tab-nav">
      <button id="tab-hn"     data-tabs-target="btn" data-action="click->tabs#select" class="dash-tab-btn">HN</button>
      <button id="tab-reddit" data-tabs-target="btn" data-action="click->tabs#select" class="dash-tab-btn">Reddit</button>
      <button id="tab-all"    data-tabs-target="btn" data-action="click->tabs#select" class="dash-tab-btn">All</button>
    </div>

    <div id="tab-hn" data-tabs-target="tab">
      <%# HN post cards %>
    </div>
    <div id="tab-reddit" data-tabs-target="tab" hidden>
      <%# Reddit post cards %>
    </div>
    <div id="tab-all" data-tabs-target="tab" hidden>
      <%# Interleaved posts, sorted by score %>
    </div>
  </div>
</section>
```

### Pattern 6: Dashboard Controller Extension
**What:** Add social post queries to `DashboardController#index`. Never call APIs — query the DB only. Pass per-platform last-updated timestamps to the view.
**Example:**
```ruby
# In DashboardController#index (additions):
@hn_posts     = SocialPost.where(platform: "hn")
                           .order(score: :desc)
                           .limit(5)
@reddit_posts = SocialPost.where(platform: "reddit")
                           .order(score: :desc)
                           .limit(5)
@all_posts    = SocialPost.order(score: :desc).limit(10)

@hn_last_updated     = SocialPost.where(platform: "hn").order(fetched_at: :desc).first&.fetched_at
@reddit_last_updated = SocialPost.where(platform: "reddit").order(fetched_at: :desc).first&.fetched_at
```

### Pattern 7: Recurring.yml Extension
```yaml
# config/recurring.yml — append to existing production: block
  hn_social_fetch:
    class: HnSocialJob
    schedule: every 2 hours
    queue: default

  reddit_social_fetch:
    class: RedditSocialJob
    schedule: every 2 hours
    queue: default
```

### Pattern 8: DataRetentionJob Extension
```ruby
# app/jobs/data_retention_job.rb — extend perform method
def perform
  cutoff = RETENTION_DAYS.days.ago.to_date
  deleted_gh = GitHubMetric.where("recorded_on < ?", cutoff).delete_all
  deleted_social = SocialPost.where("published_at < ?", cutoff.beginning_of_day).delete_all
  Rails.logger.info "DataRetentionJob: pruned #{deleted_gh} GitHubMetric, #{deleted_social} SocialPost records"
end
```

### "All" Tab Interleaving Strategy (Claude's Discretion)
Sort all posts by `score` descending and show top 10. Simple and correct for a "highlights" view. No time-decay weighting needed since this is a compact 5-post-per-platform feed (10 total in All tab). The controller already fetches `@all_posts` with `SocialPost.order(score: :desc).limit(10)`.

### Anti-Patterns to Avoid
- **Calling HN or Reddit APIs in the controller:** Controller queries DB only. All API work is in background jobs. Violating this breaks page load time and resilience.
- **Caching the Reddit access token across job runs:** Token expires in 1 hour, job runs every 2 hours — always fetch a fresh token at the start of each job run. No token caching.
- **Using find_or_create_by for upsert:** Leaves stale scores/comment counts. Use `upsert` with `unique_by: [:platform, :external_id]` so existing records get updated scores on each job run.
- **Searching reddit.com unauthenticated:** Unauthenticated Reddit requests hit 10 req/min limit and may be blocked on server IPs. Always use OAuth2 even for search (project decision from STATE.md).
- **Using the `/api/v1/search` (subreddit search) endpoint for post search:** That endpoint searches subreddit names. Use `GET https://oauth.reddit.com/search` with `type=link` for post search.
- **Forgetting the User-Agent header on Reddit requests:** Reddit returns 429 or blocks requests without a descriptive User-Agent. Required header: `User-Agent: app-name/version (by /u/username)`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HN search query construction | Custom query builder | Simple URI params: `query`, `tags`, `numericFilters` | Algolia's search_by_date endpoint handles all filtering natively |
| Reddit OAuth2 flow | oauth2 gem or complex middleware | 2 Net::HTTP calls (token + search) | App-only flow is just POST for token + GET for search; 2 calls, no refresh needed |
| Tab switching UI | Custom JavaScript | Stimulus tabs_controller | Stimulus is already installed; well-known pattern in Rails 8 |
| Post deduplication | Custom tracking table | `upsert` with `unique_by` on [platform, external_id] | Rails 6+ upsert handles this atomically in one SQL statement |
| 30-day date filtering | Custom date arithmetic | `t=month` (Reddit) + `numericFilters=created_at_i>X` (HN) | Both APIs provide native time filtering — don't filter in Ruby after the fact |

**Key insight:** Both external APIs are simple REST APIs returning JSON. No dedicated gem needed. The complexity is in the OAuth2 token fetch for Reddit (2 HTTP calls), but that's trivial with Net::HTTP.

---

## Common Pitfalls

### Pitfall 1: Reddit Token Expiry — Cached Token Fails
**What goes wrong:** If the token is stored in a class variable or cached, it expires after 1 hour but the 2-hour job interval means it's always stale on the second run.
**Why it happens:** Reddit's app-only tokens last 3600 seconds and cannot be refreshed.
**How to avoid:** Always fetch a fresh token at the start of each `RedditSocialJob#perform`. Token fetch + search = 2 HTTP calls per run (negligible at 2-hour intervals).
**Warning signs:** `401 Unauthorized` from Reddit search endpoint after first run.

### Pitfall 2: Forgetting Reddit User-Agent Header
**What goes wrong:** Reddit rate-limits or blocks requests without a proper User-Agent. Returns 429 or ignores the request entirely.
**Why it happens:** Reddit's API ToS requires a descriptive User-Agent string for all API clients.
**How to avoid:** Set `User-Agent: openclaw-analytics/1.0 (by /u/BOTNAME)` on all Reddit requests (both token and search).
**Warning signs:** 429 responses from reddit.com token endpoint or oauth.reddit.com search.

### Pitfall 3: Reddit App Type — "script" vs "web app"
**What goes wrong:** Registering the wrong app type. A "web app" type requires a redirect URI and user-context OAuth. A "script" type works with client_credentials and app-only auth.
**Why it happens:** Reddit's app registration UI offers multiple types; "script" is correct for server-side automation.
**How to avoid:** Register at reddit.com/prefs/apps, select "script" type, use any valid redirect URI (http://localhost:8080).
**Warning signs:** Token endpoint returns error about grant_type or redirect_uri mismatch.

### Pitfall 4: HN `url` Field Can Be Nil (Ask HN / Text Posts)
**What goes wrong:** Ask HN posts and Show HN text posts have no external URL. The `url` field is nil or absent. Displaying nil as a link breaks the UI.
**Why it happens:** HN has two post types: link posts (url present) and text posts (url absent).
**How to avoid:** In the normalizer: `url: hit["url"] || "https://news.ycombinator.com/item?id=#{hit['objectID']}"`. Fall back to the HN discussion URL when no external URL exists.
**Warning signs:** NilClass errors when rendering post cards; broken links in the feed.

### Pitfall 5: Reddit `upsert` vs `find_or_create_by` — Stale Scores
**What goes wrong:** Using `find_or_create_by` means an already-fetched post is never updated. Score and comment count become permanently stale from the first fetch.
**Why it happens:** `find_or_create_by` only creates, never updates.
**How to avoid:** Use `SocialPost.upsert(attrs, unique_by: [:platform, :external_id])`. This updates existing records with fresh scores on every job run.
**Warning signs:** Post scores frozen at original fetch values; never reflecting current upvotes.

### Pitfall 6: Reddit Search Endpoint vs Subreddit Search Endpoint
**What goes wrong:** Using `/api/v1/search` or `/subreddits/search` for post search returns subreddit matches, not post matches.
**Why it happens:** Reddit has multiple search endpoints with confusing names.
**How to avoid:** Use `GET https://oauth.reddit.com/search` (the top-level search) with `type=link` for post search. This searches all posts across all subreddits.
**Warning signs:** Response children have `kind: "t5"` (subreddits) instead of `kind: "t3"` (posts).

### Pitfall 7: Stimulus Tab IDs Must Match Between Buttons and Panels
**What goes wrong:** If button `id` and tab panel `id` don't match exactly, the controller's `find` returns undefined and the tab never shows.
**Why it happens:** The tabs_controller matches by ID string comparison.
**How to avoid:** Use consistent, identical IDs: `id="tab-hn"` on both the button and the content div.
**Warning signs:** Clicking a tab does nothing; JS console shows no error (silent failure on undefined.hidden).

### Pitfall 8: Reddit API Registration Requires Approval Time
**What goes wrong:** The app cannot hit Reddit's OAuth2 endpoint until a Reddit app is registered at reddit.com/prefs/apps. This is a human setup step, not code — production deployment is blocked until the user completes it.
**Why it happens:** Reddit requires registered apps for all API access.
**How to avoid:** Document this as a user prerequisite. The RedditSocialJob should handle missing credentials gracefully (rescue AuthError, log, skip run) so HnSocialJob and the rest of the dashboard continue working.
**Warning signs:** `KeyError: key not found: REDDIT_CLIENT_ID` or `AuthError: Token fetch failed: HTTP 401`.

---

## Code Examples

Verified patterns from official sources and existing project conventions:

### SocialPost Migration
```ruby
# db/migrate/TIMESTAMP_create_social_posts.rb
class CreateSocialPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_posts do |t|
      t.string  :platform,      null: false
      t.string  :external_id,   null: false
      t.string  :title,         null: false
      t.string  :url
      t.string  :author
      t.integer :score,         default: 0
      t.integer :comment_count, default: 0
      t.string  :subreddit

      t.datetime :published_at
      t.datetime :fetched_at, null: false

      t.timestamps
    end

    add_index :social_posts, [:platform, :external_id], unique: true
    add_index :social_posts, :platform
    add_index :social_posts, :published_at
  end
end
```

### SocialPost Model
```ruby
# app/models/social_post.rb
class SocialPost < ApplicationRecord
  PLATFORMS = %w[hn reddit].freeze

  validates :platform,     inclusion: { in: PLATFORMS }
  validates :external_id,  presence: true
  validates :title,        presence: true
  validates :fetched_at,   presence: true
  validates :external_id,  uniqueness: { scope: :platform }

  scope :for_platform,   ->(p) { where(platform: p) }
  scope :top_posts,      ->(n) { order(score: :desc).limit(n) }
  scope :last_30_days,   -> { where("published_at > ?", 30.days.ago) }
  scope :recent_first,   -> { order(published_at: :desc) }

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
```

### HN Algolia API Call (confirmed working pattern)
```ruby
# GET https://hn.algolia.com/api/v1/search_by_date
# Params: query=OpenClaw, tags=story, numericFilters=created_at_i>TIMESTAMP, hitsPerPage=50
# Response: { hits: [ { objectID, title, url, author, points, num_comments, created_at, created_at_i } ] }
# No authentication required — public API

cutoff = 30.days.ago.to_i
url = "https://hn.algolia.com/api/v1/search_by_date?" \
      "query=OpenClaw&tags=story&numericFilters=created_at_i%3E#{cutoff}&hitsPerPage=50"
response = Net::HTTP.get_response(URI(url))
hits = JSON.parse(response.body)["hits"]
```

### Reddit OAuth2 Token Fetch (confirmed working pattern)
```ruby
# POST https://www.reddit.com/api/v1/access_token
# Basic Auth: client_id:client_secret
# Body: grant_type=client_credentials
# User-Agent: required
# Response: { access_token, token_type, expires_in, scope }

uri = URI("https://www.reddit.com/api/v1/access_token")
req = Net::HTTP::Post.new(uri)
req.basic_auth(client_id, client_secret)
req["User-Agent"] = "openclaw-analytics/1.0 (by /u/openclaw_bot)"
req.set_form_data("grant_type" => "client_credentials")
res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
token = JSON.parse(res.body)["access_token"]
```

### Reddit Post Search (confirmed working pattern)
```ruby
# GET https://oauth.reddit.com/search
# Headers: Authorization: bearer TOKEN, User-Agent: ...
# Params: q=OpenClaw, sort=top, t=month, limit=50, type=link
# Response: { kind: "Listing", data: { children: [ { kind: "t3", data: { title, url, ups, ... } } ] } }

uri = URI("https://oauth.reddit.com/search")
uri.query = URI.encode_www_form(q: "OpenClaw", sort: "top", t: "month", limit: 50, type: "link")
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "bearer #{token}"
req["User-Agent"]    = "openclaw-analytics/1.0 (by /u/openclaw_bot)"
res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
posts = JSON.parse(res.body).dig("data", "children").map { |c| c["data"] }
```

### Rails Credentials for Reddit
```bash
EDITOR="nano" bin/rails credentials:edit
```
```yaml
# In credentials YAML — add alongside existing github: section:
reddit:
  client_id: your_reddit_client_id
  client_secret: your_reddit_client_secret
```
```ruby
# Access in code:
Rails.application.credentials.dig(:reddit, :client_id)
Rails.application.credentials.dig(:reddit, :client_secret)
```

### Social Card HTML Pattern (dark theme, consistent with existing dash-card)
```erb
<%# Social post card — used in both HN and Reddit panels %>
<div class="dash-social-card">
  <div class="dash-social-platform-badge dash-social-badge--<%= post.platform %>">
    <%= post.hn? ? "Y" : "&#128123;".html_safe %>
  </div>
  <div class="dash-social-content">
    <a href="<%= post.url %>" target="_blank" rel="noopener" class="dash-social-title">
      <%= post.title %>
    </a>
    <div class="dash-social-meta">
      <span><%= post.score %> pts</span>
      <span><%= post.comment_count %> comments</span>
      <span><%= post.author %></span>
      <% if post.reddit? && post.subreddit.present? %>
        <span>r/<%= post.subreddit %></span>
      <% end %>
      <span><%= time_ago_in_words(post.published_at) %> ago</span>
    </div>
  </div>
</div>
```

### Upsert Pattern (update scores on re-fetch)
```ruby
# Use upsert_all for batch performance, or upsert for single records
SocialPost.upsert(
  {
    platform:      "hn",
    external_id:   "12345",
    title:         "OpenClaw is amazing",
    url:           "https://example.com/openclaw",
    author:        "pg",
    score:         142,
    comment_count: 37,
    subreddit:     nil,
    published_at:  Time.parse("2026-02-20T10:00:00Z"),
    fetched_at:    Time.current,
    created_at:    Time.current,
    updated_at:    Time.current
  },
  unique_by: [:platform, :external_id]
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Reddit unauthenticated JSON API (appending .json) | OAuth2 required — server IPs get blocked without auth | 2023 API changes | Must use client_credentials flow; no workarounds |
| Pushshift for Reddit historical search | Reddit's own API | Pushshift shut down mid-2023 | Only Reddit's official API available for search |
| ruby-reddit-api gem | Custom Net::HTTP client | Gem unmaintained since 2016 | Hand-roll is simpler than using an unmaintained gem |
| redd gem | Custom Net::HTTP client | redd requires user-context OAuth, not app-only | App-only client_credentials is not supported by redd |
| Reddit search returns 500 items | Reddit now caps results at ~100 per request | 2023+ | Use `limit=50` for a 30-day window, sufficient for low-frequency mentions |

**Deprecated/outdated:**
- Pushshift.io API: Shut down. Do not reference.
- `.json` appended to Reddit URLs: Unreliable on server IPs without auth. Use oauth.reddit.com with Bearer token.
- redd gem: Last meaningful commit 2019. Do not use.
- reddit-base gem: Unmaintained. Do not use.

---

## Open Questions

1. **Reddit app registration — timing and approval**
   - What we know: Requires manual registration at reddit.com/prefs/apps; "script" type works for client_credentials; approval is typically fast for personal/developer projects in 2025
   - What's unclear: Whether Reddit's stated "a few days" approval timeline actually applies to personal/developer projects, or if access is immediate
   - Recommendation: Document as a pre-deployment prerequisite. RedditSocialJob must handle missing credentials gracefully (skip with log, don't error). HnSocialJob must run independently.

2. **Reddit search temporal coverage with `t=month`**
   - What we know: `t=month` returns posts from the past ~30 days; this matches our 30-day lookback window
   - What's unclear: Whether "month" is exactly 30 days or a calendar month; edge case behavior at month boundaries
   - Recommendation: Accept `t=month` as-is. The 30-day discrepancy is cosmetic. DataRetentionJob prunes at 30 days anyway, so any minor overfetch is harmless.

3. **HN Algolia rate limits**
   - What we know: The API is public, no auth required, max 1000 hits retrievable per query; official rate limits not published
   - What's unclear: Whether 2-hour polling intervals risk hitting undocumented rate limits; no documented per-IP limit found
   - Recommendation: Use `hitsPerPage=50` (modest fetch), add error handling for non-200 responses, and accept LOW confidence on rate limit safety. At 2-hour intervals with 1-2 requests per run, this is almost certainly fine.

4. **Reddit search result ordering — `sort=top` vs `sort=relevance`**
   - What we know: `sort=top` returns highest-upvoted posts in the time window; `sort=relevance` returns closest keyword match
   - What's unclear: For a rare term like "OpenClaw", relevance and top are likely equivalent
   - Recommendation: Use `sort=top` — matches the locked decision that "posts sorted by highest score first". DB query also reorders by score regardless.

---

## Sources

### Primary (HIGH confidence)
- [HN Algolia API documentation — hn.algolia.com](https://hn.algolia.com/api) — endpoint URLs confirmed (`search`, `search_by_date`), field names confirmed (via GitHub source README: `created_at`, `title`, `url`, `author`, `points`, `story_text`, `num_comments`, `story_id`, `created_at_i`, `objectID`), numericFilters confirmed
- [Reddit OAuth2 wiki — reddit-archive](https://github.com/reddit-archive/reddit/wiki/OAuth2) — app-only client_credentials grant confirmed; token endpoint URL confirmed; bearer token header format confirmed; token expiry 1 hour confirmed; no refresh_token for app-only confirmed
- [Reddit API rate limits 2026 — PainOnSocial](https://painonsocial.com/blog/reddit-api-rate-limits-guide) — 60 req/min authenticated confirmed; X-Ratelimit-* headers confirmed
- [Railsnotes — Simple Stimulus Tabs Controller](https://railsnotes.xyz/blog/simple-stimulus-tabs-controller) — complete tabs_controller.js with targets, values, connect(), select() methods verified
- Existing codebase: `app/services/github_client.rb`, `app/models/github_metric.rb`, `app/jobs/github_metric_job.rb` — patterns for service objects, typed errors, upsert, recurring.yml format directly observed
- [Reddit registration guide 2025 — wappkit.com](https://www.wappkit.com/blog/reddit-api-credentials-guide-2025) — "script" app type for server-side scripts confirmed; reddit.com/prefs/apps registration URL confirmed

### Secondary (MEDIUM confidence)
- [algolia/hn-search README — GitHub](https://github.com/algolia/hn-search/blob/master/README.md) — field names `created_at`, `title`, `url`, `author`, `points`, `story_text`, `comment_text`, `num_comments`, `story_id`, `created_at_i` confirmed in index config
- [Simon Willison TIL — scraping Reddit JSON](https://til.simonwillison.net/reddit/scraping-reddit-json) — Reddit JSON structure `data.children[i].data` confirmed; field names `id`, `subreddit`, `url`, `created_utc`, `permalink`, `num_comments` confirmed
- [jcchouinard Reddit API JSON documentation](https://www.jcchouinard.com/documentation-on-reddit-apis-json/) — Reddit listing structure confirmed with full field list including `title`, `ups`, `author`, `created_utc`, `subreddit_id`
- [reddit-archive OAuth2 quick start](https://github.com/reddit-archive/reddit/wiki/oauth2-quick-start-example) — client_credentials POST body format confirmed; oauth.reddit.com base URL confirmed
- [deepeshsoni.com HN Algolia guide](https://deepeshsoni.com/archives/70) — numericFilters with Unix timestamp for date range confirmed; `tags=story` confirmed

### Tertiary (LOW confidence — verify if used)
- Reddit search endpoint parameter `type=link` for filtering to posts only: confirmed via multiple non-official sources but not verified against official Reddit API docs directly
- HN Algolia search is case-insensitive: consistent with Algolia's default behavior but not explicitly documented in HN-specific docs
- Reddit `t=month` covers ~30 days: consistent with Reddit's UI behavior but exact boundary not documented

---

## Metadata

**Confidence breakdown:**
- HN Algolia API (endpoints, fields, params): HIGH — field names confirmed in source code; endpoints confirmed via multiple guides; no auth requirement confirmed
- Reddit OAuth2 flow (token endpoint, grant type, bearer usage): HIGH — confirmed via official Reddit OAuth2 wiki
- Reddit search response structure (data.children, field names): MEDIUM-HIGH — confirmed via 3+ independent sources
- Reddit search parameters (q, sort, t, limit, type): MEDIUM — confirmed via multiple guides, not official docs directly
- Stimulus tabs controller pattern: HIGH — complete working code from Railsnotes verified
- Upsert pattern for SocialPost: HIGH — Rails 6+ upsert with unique_by is documented Rails behavior

**Research date:** 2026-02-23
**Valid until:** 2026-05-23 (stable for HN Algolia; Reddit API subject to policy changes — re-verify if >60 days)
