# Phase 1: Foundation + GitHub Pipeline - Research

**Researched:** 2026-02-23
**Domain:** Rails 8 + GitHub API (Octokit) + SQLite WAL + Solid Queue + Chartkick/Chart.js
**Confidence:** HIGH (core stack verified via official docs and RubyGems; specific GitHub API behavior verified via official GitHub docs)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Chart types & layout
- Claude's discretion on chart type per metric (line vs area vs bar) — pick what communicates best
- Charts arranged in a 2-column grid
- Claude's discretion on chart type for non-time-series metrics (issues open/closed, PR states, etc.)
- Hover tooltips on charts to show exact values, but no zoom/pan/interactive features

#### Metric visual hierarchy
- Top tier (most prominent): stars, forks, and commit frequency
- Secondary tier: issues, PRs, contributors, releases
- Every chart/metric card gets a headline summary number above it (e.g., "1,247 stars")
- Latest release displayed as a single card (name, date, link) — not a chart
- Claude's discretion on contributor count display (big number + trend vs chart)

#### Dashboard page structure
- Single scrolling page with sections and anchor links
- Sticky top nav bar with section names as clickable jump links
- Minimal header — just "OpenClaw" and "Analytics Dashboard" subtitle
- Dark theme — dark backgrounds with vibrant chart colors, modern developer dashboard feel

#### Empty & loading states
- First deploy with no data: each chart area shows "Collecting data..." with estimated time until first data
- Partial data (less than 30 days): render whatever data exists, x-axis adapts to available range
- API errors: each affected chart shows its own error indicator, unaffected charts display normally
- Per-section "last updated" timestamps showing when each metric was last refreshed

### Claude's Discretion
- Specific chart type per metric (line, area, bar, donut, sparkline, etc.)
- Chart colors, spacing, typography within dark theme
- Contributor count display format
- Loading skeleton/animation design
- Error indicator design
- Exact section groupings for the nav

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | SQLite WAL mode enabled on all databases to prevent write contention from concurrent background jobs | WAL is automatic since Rails 7.1 but must be verified; multi-DB setup needs each DB confirmed |
| INFRA-02 | Shared rate-limit-aware HTTP client module with exponential backoff and typed errors (RateLimitError, AuthError, NotFoundError) | Octokit raises typed exceptions; wrapper module maps these to typed errors |
| INFRA-03 | API credentials stored in Rails credentials or ENV variables, never hardcoded | Rails credentials pattern documented: `Rails.application.credentials.github[:token]` |
| INFRA-04 | Solid Queue recurring job schedule configured for all data fetch jobs | Recurring.yml with Fugit syntax: `every 6 hours`, `every day at 3am` |
| INFRA-05 | Data retention job prunes records older than 30 days daily | Solid Queue recurring job + ActiveRecord `where("recorded_on < ?", 30.days.ago).delete_all` |
| GH-01 | Dashboard displays star count over time as a line chart (30-day rolling window) | Snapshot approach: job records `stargazers_count` from GET /repos endpoint every 6h; Chartkick line_chart |
| GH-02 | Dashboard displays fork count over time as a line chart (30-day rolling window) | Same snapshot approach as GH-01; `forks_count` field on repo object |
| GH-03 | Dashboard displays open vs. closed issue counts | Search API for separate issue vs PR counts; `open_issues_count` on repo object includes PRs (needs disambiguation) |
| GH-04 | Dashboard displays PR activity (open/merged/closed) | `client.pull_requests(repo, state: 'all')` for PR states; snapshot counts per state |
| GH-05 | Dashboard displays commit frequency (per day) | `commit_activity_stats` endpoint returns 52 weeks of daily commit arrays; trim to 30 days |
| GH-06 | Dashboard displays contributor count and new contributor growth | `contributors_stats` returns per-contributor weekly data; count unique contributors |
| GH-07 | Dashboard displays latest release info and release cadence | `client.latest_release(repo)` and `client.releases(repo)` for release list |
| GH-08 | Background job fetches GitHub metrics via Octokit every 6 hours | Solid Queue recurring.yml: `schedule: every 6 hours` |
| GH-09 | GitHub data stored in GitHubMetric model (metric_type + value + recorded_on, unique index) | ActiveRecord model with string metric_type, decimal value, date recorded_on; unique_index on [metric_type, recorded_on] |
| DASH-02 | Time-series charts rendered via Chartkick/Chart.js with real data (replacing static placeholders) | Chartkick 5.2.1 already in Gemfile; `line_chart`, `area_chart`, `bar_chart` helpers |
| DASH-05 | Page loads under 3 seconds (all data pre-fetched by background jobs) | Controller queries DB (never API); Solid Cache for fragment caching; no N+1 |
| DASH-06 | Public-facing, no authentication required | No Rails auth generator used; ApplicationController has no auth by default in this app |
</phase_requirements>

---

## Summary

This phase establishes the entire Rails 8 stack for background data ingestion and dashboard rendering. The project already has Rails 8.1.2, Solid Queue 1.3.1, Chartkick 5.2.1 with Chart.js, and SQLite3 installed. No new infrastructure gems are needed; the work is wiring together existing pieces with a new model, job, and views.

The GitHub API strategy has one critical design point: there is no historical star/fork timeline endpoint. The API only provides current totals via `GET /repos/{owner}/{repo}`. Time-series charts are built by recording snapshots on each 6-hour job run and accumulating them over 30 days. By contrast, commit activity comes from the `stats/commit_activity` endpoint which returns 52 weeks of pre-computed daily data. The stats endpoints have a 202/retry behavior on first call that must be handled explicitly.

WAL mode is automatic in Rails 7.1+, so INFRA-01 does not require explicit database.yml changes. However, verifying the WAL setting is active across all four production databases (primary, queue, cache, cable) is prudent. The `open_issues_count` field on the repo object includes pull requests — separate API calls are needed for accurate issue-only vs PR-only counts.

**Primary recommendation:** Build a single `GithubMetricJob` that fetches all metrics in one job run. Use a shared `GithubClient` service object wrapping Octokit with typed error classes. Store each metric as a named snapshot row in `github_metrics`. Let Chartkick render everything from DB queries.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| octokit | ~> 10.0 | GitHub API Ruby client | Official GitHub-supported gem; wraps all REST endpoints; typed exceptions |
| chartkick | 5.2.1 | Chart helpers for ERB templates | Already installed; one-line chart rendering with Chart.js |
| solid_queue | 1.3.1 | Background job processing with recurring schedule | Already installed; runs in-Puma via SOLID_QUEUE_IN_PUMA=true |
| sqlite3 | 2.9.x | Database adapter | Already installed; WAL mode automatic in Rails 7.1+ |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| solid_cache | 1.0.10 | Fragment caching for dashboard partials | Cache rendered chart HTML to hit sub-3s page load |
| faraday | (octokit dep) | HTTP middleware under Octokit | Not added directly; Octokit brings it |

### Not Needed (Already Present)
The Gemfile already includes `chartkick`, `solid_queue`, `solid_cache`, and `sqlite3`. The vendor/javascript directory already has `chartkick.js` and `Chart.bundle.js`. The importmap already pins both.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| octokit | faraday + raw HTTP | Octokit provides typed methods, auto-pagination, typed exceptions — no reason to hand-roll |
| Chartkick | Chart.js directly | Chartkick is already wired; direct Chart.js requires Stimulus controller boilerplate |
| Solid Queue recurring | rake task + cron | Solid Queue recurring.yml is already the project's job runner; cron requires server config outside Rails |

**Installation:**
```bash
bundle add octokit
# or in Gemfile:
gem "octokit", "~> 10.0"
bundle install
```

---

## Architecture Patterns

### Recommended Project Structure
```
app/
├── models/
│   └── github_metric.rb          # metric_type, value, recorded_on; query scopes
├── jobs/
│   ├── github_metric_job.rb      # Main 6-hour fetch job
│   └── data_retention_job.rb     # Daily pruning job
├── services/
│   └── github_client.rb          # Octokit wrapper with typed errors
├── controllers/
│   └── dashboard_controller.rb   # Queries DB; assigns @metrics for view
└── views/
    └── dashboard/
        └── index.html.erb        # Chartkick charts + sections + sticky nav

config/
├── recurring.yml                  # Schedule entries for both jobs
└── credentials.yml.enc            # github: { token: ... }
```

### Pattern 1: Snapshot Accumulation for Time-Series
**What:** Stars and forks have no history endpoint. Record current totals on each job run as a dated snapshot. Chartkick plots the accumulated rows as a time-series.
**When to use:** Any metric where the API returns only current state (not history).
**Example:**
```ruby
# In GithubMetricJob
repo = client.repository("owner/repo")
GitHubMetric.find_or_create_by!(
  metric_type: "stars",
  recorded_on: Date.today
) do |m|
  m.value = repo.stargazers_count
end
```

### Pattern 2: Stats Endpoint with 202 Retry
**What:** GitHub's stats endpoints (`commit_activity_stats`, `contributors_stats`) return 202 on first call while GitHub computes the data in the background. Must retry.
**When to use:** All `/stats/*` endpoint calls.
**Example:**
```ruby
# In GithubClient
def commit_activity_stats
  retries = 0
  begin
    stats = @client.commit_activity_stats(repo_slug)
    raise Octokit::AcceptedResponse if stats.nil? || stats.empty?
    stats
  rescue Octokit::AcceptedResponse, StandardError => e
    retries += 1
    raise StatsUnavailableError, "GitHub stats still computing" if retries >= 3
    sleep(2 ** retries)
    retry
  end
end
```
Note: `commit_activity_stats` only works for repos with fewer than 10,000 commits. Returns 52 weeks of `{days: [0,3,26,20,39,1,0], total: 89, week: 1336280400}` objects (days array starts Sunday).

### Pattern 3: GitHubMetric Model — One Row Per Metric Per Day
**What:** Single polymorphic table stores all metric types. `metric_type` is a string key (e.g., `"stars"`, `"forks"`, `"open_issues"`, `"closed_issues"`, `"open_prs"`, `"merged_prs"`, `"commit_frequency"`, `"contributor_count"`). `value` stores the numeric value. `recorded_on` is a date.
**When to use:** Always — this is the only storage model (GH-09).
**Schema:**
```ruby
create_table :github_metrics do |t|
  t.string :metric_type, null: false
  t.decimal :value, null: false, precision: 15, scale: 4
  t.date :recorded_on, null: false
  t.timestamps
end
add_index :github_metrics, [:metric_type, :recorded_on], unique: true
```

### Pattern 4: Separate Issue vs PR Counts via Search API
**What:** `GET /repos/:owner/:repo` returns `open_issues_count` which includes both issues AND pull requests. To get accurate separate counts, use the Search API.
**When to use:** GH-03 (issue counts) and GH-04 (PR counts).
**Example:**
```ruby
# Open issues only (exclude PRs)
open_issues = @client.search_issues("repo:#{slug} is:issue is:open").total_count

# PRs by state
open_prs    = @client.search_issues("repo:#{slug} is:pr is:open").total_count
merged_prs  = @client.search_issues("repo:#{slug} is:pr is:merged").total_count
closed_prs  = @client.search_issues("repo:#{slug} is:pr is:closed").total_count
```
Note: Search API rate limits are separate (30 requests/minute for authenticated users).

### Pattern 5: Chartkick with Chart.js Dark Theme Options
**What:** Pass `library:` options hash to Chartkick chart helpers to configure Chart.js internals. Global defaults set in an initializer.
**When to use:** Always — dark theme requires explicit Chart.js color configuration.
**Example:**
```ruby
# config/initializers/chartkick.rb
Chartkick.options = {
  colors: ["#60a5fa", "#34d399", "#f97316", "#a78bfa", "#fb7185"],
  library: {
    plugins: {
      legend: { labels: { color: "#94a3b8" } },
      tooltip: { backgroundColor: "#1e293b", titleColor: "#f1f5f9", bodyColor: "#94a3b8" }
    },
    scales: {
      x: { ticks: { color: "#64748b" }, grid: { color: "#1e293b" } },
      y: { ticks: { color: "#64748b" }, grid: { color: "#1e293b" } }
    }
  }
}

# In view
<%= line_chart @stars_data, height: "250px", points: false, curve: false %>
```

### Pattern 6: Solid Queue Recurring Schedule
**What:** `config/recurring.yml` uses Fugit syntax. The production block already exists in the project with a `clear_solid_queue_finished_jobs` entry.
**When to use:** Adding new recurring jobs — append to the existing `production:` block.
**Example:**
```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  github_metrics_fetch:
    class: GithubMetricJob
    schedule: every 6 hours
    queue: default

  data_retention_prune:
    class: DataRetentionJob
    schedule: every day at 3am
    queue: default
```

### Anti-Patterns to Avoid
- **Making API calls in controller actions:** The controller must only query the database. API calls belong in background jobs only. Violating this breaks DASH-05 (3-second page load) and makes the page brittle to API failures.
- **Using `auto_paginate: true` for large result sets in a time-limited job:** Auto-pagination fetches all pages in one call. For repos with thousands of stars, this exhausts rate limits. Prefer snapshot approach (record current total) over paginating stargazers.
- **Storing time-series as JSON blobs:** Each metric-per-day as its own row enables efficient scoped queries. JSON blobs can't be indexed, grouped, or pruned with simple SQL.
- **One giant job with no error isolation:** If one metric fetch fails, it should not prevent other metrics from saving. Rescue per-metric, log the error, continue.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub API HTTP client | Custom Faraday setup | `octokit` gem | Octokit handles auth headers, pagination, error mapping, rate-limit metadata |
| Cron scheduling | Rake tasks + system cron | Solid Queue recurring.yml | Stays in the Rails process; no server config; already installed |
| Chart rendering | Stimulus + raw Chart.js | Chartkick helpers | Already wired in importmap; one-line ERB; data format is hash/array |
| Rate limit backoff | Custom retry loops | rescue `Octokit::TooManyRequests` + check `rate_limit.resets_at` | Octokit exposes rate limit metadata directly |
| Fragment caching | Custom cache keys | `cache` helper with `solid_cache` | Already configured in production env |

**Key insight:** The entire infrastructure (queue, cache, charts, SQLite) is already installed. This phase is about wiring, not installing.

---

## Common Pitfalls

### Pitfall 1: open_issues_count Includes Pull Requests
**What goes wrong:** Using `repo.open_issues_count` as the "open issues" metric produces numbers that include open pull requests. Users see unexpectedly high issue counts.
**Why it happens:** GitHub's REST API considers every pull request an issue. The `open_issues_count` field reflects combined open issues + open PRs.
**How to avoid:** Use the Search API with `is:issue` and `is:pr` qualifiers to get separate counts. Costs 4 search API calls per job run (open issues, closed issues, open PRs, merged PRs). Search API rate limit is 30 requests/minute authenticated — well within budget for a 6-hour job.
**Warning signs:** Issue count is consistently higher than what GitHub shows on the repository page under "Issues" tab.

### Pitfall 2: Stats Endpoints Return 202 on First Call
**What goes wrong:** `client.commit_activity_stats` returns nil or empty when GitHub hasn't cached the data yet. If not handled, the job saves zero-value metrics or crashes.
**Why it happens:** GitHub fires a background job to compute stats on first request. The API returns 202 Accepted immediately with an empty body.
**How to avoid:** Wrap stats calls in a retry loop (max 3 retries, exponential backoff). On 202, sleep and retry. Accept that on a brand-new repo or after a long idle period, the first job run may not store commit stats.
**Warning signs:** `commit_activity_stats` returns `[]` or raises an error on first execution.

### Pitfall 3: WAL Mode and Multiple Databases
**What goes wrong:** Concurrent Solid Queue workers and the web process write to the same SQLite file. Without WAL, `SQLite3::BusyException` errors occur under load.
**Why it happens:** Rails sets WAL mode automatically since 7.1 — but only for databases opened through the adapter. Verify all four databases (primary, queue, cache, cable) have WAL active.
**How to avoid:** WAL is applied automatically by Rails 8.1 for all SQLite connections via the adapter's `configure_connection` method. No explicit `database.yml` pragma needed. The Kamal deploy config uses a persistent Docker volume (`analytics_dashboard_storage:/rails/storage`) so WAL journal files persist between restarts.
**Warning signs:** `SQLite3::BusyException: database is locked` in production logs.

### Pitfall 4: Commit History Strategy — Stats vs Stargazer Endpoint
**What goes wrong:** Attempting to page through `GET /repos/:owner/:repo/commits` with `since: 30.days.ago` to count commits per day is expensive (many pages, counts toward 5,000/hr rate limit) and slow.
**Why it happens:** Naively treating all GitHub data as list-then-aggregate.
**How to avoid:** Use `commit_activity_stats` which returns the last year of commit activity in one call (52 weeks × daily breakdown). Trim to last 30 days. Far more efficient.
**Warning signs:** Job taking minutes to run; rate limit warnings in logs.

### Pitfall 5: Stars Have No Historical Endpoint
**What goes wrong:** Expecting to backfill 30 days of star history on first deploy. The GitHub API provides starred_at timestamps via `GET /repos/:owner/:repo/stargazers` with the `application/vnd.github.star+json` Accept header — but paginating all stargazers is expensive (1 page per 100 users, potentially hundreds of pages for popular repos).
**Why it happens:** Assumption that the API supports history queries.
**How to avoid:** Accept that star/fork time-series starts from the first job run. Show "Collecting data..." on the star chart for up to 30 days. Do NOT paginate all stargazers to reconstruct history. The snapshot approach (current total recorded daily) is correct and sufficient.
**Warning signs:** Job taking very long on first run; rate limit exhaustion.

### Pitfall 6: No Authentication = 60 req/hr Rate Limit
**What goes wrong:** Deploying without a GitHub PAT means the app hits the 60 req/hr unauthenticated limit immediately. A single job run makes ~10+ API calls.
**Why it happens:** Missing or invalid token in credentials.
**How to avoid:** Require `RAILS_MASTER_KEY` at deploy time (already in deploy.yml). Store token as `Rails.application.credentials.github[:token]` and validate on startup.
**Warning signs:** `Octokit::TooManyRequests` within minutes of deployment.

---

## Code Examples

Verified patterns from official sources:

### GitHub Client Service Object
```ruby
# app/services/github_client.rb
class GithubClient
  class RateLimitError < StandardError; end
  class AuthError < StandardError; end
  class NotFoundError < StandardError; end
  class StatsUnavailableError < StandardError; end

  REPO_SLUG = Rails.application.credentials.dig(:github, :repo_slug) ||
              ENV.fetch("GITHUB_REPO_SLUG")

  def initialize
    @client = Octokit::Client.new(
      access_token: Rails.application.credentials.dig(:github, :token) ||
                    ENV["GITHUB_TOKEN"]
    )
  end

  def repository
    @client.repository(REPO_SLUG)
  rescue Octokit::Unauthorized => e
    raise AuthError, e.message
  rescue Octokit::NotFound => e
    raise NotFoundError, e.message
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, "Rate limit resets at #{@client.rate_limit.resets_at}"
  end

  def commit_activity_stats
    fetch_stats { @client.commit_activity_stats(REPO_SLUG) }
  end

  def contributors_stats
    fetch_stats { @client.contributors_stats(REPO_SLUG) }
  end

  def pull_requests_count(state:)
    @client.search_issues("repo:#{REPO_SLUG} is:pr is:#{state}").total_count
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, e.message
  end

  def open_issues_count
    @client.search_issues("repo:#{REPO_SLUG} is:issue is:open").total_count
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, e.message
  end

  def closed_issues_count
    @client.search_issues("repo:#{REPO_SLUG} is:issue is:closed").total_count
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, e.message
  end

  def latest_release
    @client.latest_release(REPO_SLUG)
  rescue Octokit::NotFound
    nil
  end

  private

  def fetch_stats(&block)
    retries = 0
    loop do
      result = block.call
      return result if result.present?
      retries += 1
      raise StatsUnavailableError, "GitHub stats unavailable after #{retries} retries" if retries >= 3
      sleep(2 ** retries)
    end
  rescue Octokit::TooManyRequests => e
    raise RateLimitError, e.message
  end
end
```

### GitHubMetric Model
```ruby
# app/models/github_metric.rb
class GitHubMetric < ApplicationRecord
  METRIC_TYPES = %w[
    stars forks
    open_issues closed_issues
    open_prs merged_prs closed_prs
    commit_frequency contributor_count
    latest_release_date
  ].freeze

  validates :metric_type, inclusion: { in: METRIC_TYPES }
  validates :recorded_on, presence: true
  validates :value, presence: true
  validates :metric_type, uniqueness: { scope: :recorded_on }

  scope :for_metric, ->(type) { where(metric_type: type) }
  scope :last_30_days, -> { where(recorded_on: 30.days.ago.to_date..) }
  scope :ordered, -> { order(recorded_on: :asc) }

  def self.chart_data(metric_type)
    for_metric(metric_type)
      .last_30_days
      .ordered
      .pluck(:recorded_on, :value)
      .to_h
  end

  def self.latest_value(metric_type)
    for_metric(metric_type).order(recorded_on: :desc).first&.value
  end
end
```

### GithubMetricJob
```ruby
# app/jobs/github_metric_job.rb
class GithubMetricJob < ApplicationJob
  queue_as :default

  def perform
    client = GithubClient.new
    today = Date.today

    # Snapshot metrics (current value recorded as of today)
    record_snapshot(client, today)

    # Stats-based metrics (from stats endpoints)
    record_commit_activity(client, today)
    record_contributor_count(client, today)
  rescue GithubClient::RateLimitError => e
    Rails.logger.error "GitHub rate limit hit: #{e.message}"
    # Job ends without retry — will run again in 6 hours
  rescue => e
    Rails.logger.error "GithubMetricJob failed: #{e.class}: #{e.message}"
    raise # Re-raise to let Solid Queue handle retry
  end

  private

  def record_snapshot(client, today)
    repo = client.repository
    upsert(metric_type: "stars",    value: repo.stargazers_count, recorded_on: today)
    upsert(metric_type: "forks",    value: repo.forks_count,      recorded_on: today)

    upsert(metric_type: "open_issues",   value: safe_call { client.open_issues_count },   recorded_on: today)
    upsert(metric_type: "closed_issues", value: safe_call { client.closed_issues_count }, recorded_on: today)
    upsert(metric_type: "open_prs",      value: safe_call { client.pull_requests_count(state: "open") },   recorded_on: today)
    upsert(metric_type: "merged_prs",    value: safe_call { client.pull_requests_count(state: "merged") }, recorded_on: today)
    upsert(metric_type: "closed_prs",    value: safe_call { client.pull_requests_count(state: "closed") }, recorded_on: today)

    release = client.latest_release
    upsert(metric_type: "latest_release_date", value: release&.published_at&.to_date&.jd || 0, recorded_on: today)
  end

  def record_commit_activity(client, today)
    stats = client.commit_activity_stats
    return unless stats.present?

    # stats is array of 52 weeks, each {days: [...], total: N, week: epoch}
    # days[0] = Sunday, days[1] = Monday, ..., days[6] = Saturday
    stats.last(5).each do |week_stat|
      week_start = Time.at(week_stat[:week]).utc.to_date
      week_stat[:days].each_with_index do |count, day_index|
        date = week_start + day_index
        next if date > today
        upsert(metric_type: "commit_frequency", value: count, recorded_on: date)
      end
    end
  end

  def record_contributor_count(client, today)
    stats = client.contributors_stats
    return unless stats.present?
    upsert(metric_type: "contributor_count", value: stats.count, recorded_on: today)
  end

  def upsert(metric_type:, value:, recorded_on:)
    return if value.nil?
    GitHubMetric.find_or_create_by!(metric_type: metric_type, recorded_on: recorded_on) do |m|
      m.value = value
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Skipping invalid metric #{metric_type}: #{e.message}"
  end

  def safe_call
    yield
  rescue GithubClient::RateLimitError => e
    Rails.logger.warn "Rate limited during #{caller_locations(1,1)[0].label}: #{e.message}"
    nil
  end
end
```

### Recurring.yml Addition
```yaml
# config/recurring.yml (append to existing production: block)
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  github_metrics_fetch:
    class: GithubMetricJob
    schedule: every 6 hours
    queue: default

  data_retention_prune:
    class: DataRetentionJob
    schedule: every day at 3am
    queue: default
```

### DataRetentionJob
```ruby
# app/jobs/data_retention_job.rb
class DataRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 30

  def perform
    cutoff = RETENTION_DAYS.days.ago.to_date
    deleted = GitHubMetric.where("recorded_on < ?", cutoff).delete_all
    Rails.logger.info "DataRetentionJob: pruned #{deleted} GitHubMetric records older than #{cutoff}"
  end
end
```

### Dashboard Controller
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @stars_data       = GitHubMetric.chart_data("stars")
    @forks_data       = GitHubMetric.chart_data("forks")
    @commit_data      = GitHubMetric.chart_data("commit_frequency")
    @open_issues      = GitHubMetric.latest_value("open_issues")
    @closed_issues    = GitHubMetric.latest_value("closed_issues")
    @open_prs         = GitHubMetric.latest_value("open_prs")
    @merged_prs       = GitHubMetric.latest_value("merged_prs")
    @contributor_count = GitHubMetric.latest_value("contributor_count")
    @last_updated     = GitHubMetric.order(updated_at: :desc).first&.updated_at
  end
end
```

### Chartkick Dark Theme Initializer
```ruby
# config/initializers/chartkick.rb
Chartkick.options = {
  colors: ["#60a5fa", "#34d399", "#f97316", "#a78bfa", "#fb7185", "#fbbf24"],
  library: {
    plugins: {
      legend: {
        labels: { color: "#94a3b8", font: { size: 12 } }
      },
      tooltip: {
        backgroundColor: "#1e293b",
        titleColor: "#f1f5f9",
        bodyColor: "#94a3b8",
        borderColor: "#334155",
        borderWidth: 1
      }
    },
    scales: {
      x: {
        ticks: { color: "#64748b", font: { size: 11 } },
        grid: { color: "#1e293b" }
      },
      y: {
        ticks: { color: "#64748b", font: { size: 11 } },
        grid: { color: "#1e293b" }
      }
    }
  }
}
```

### Rails Credentials for GitHub Token
```bash
# Store the token:
EDITOR="nano" bin/rails credentials:edit

# In the credentials YAML:
# github:
#   token: ghp_your_token_here
#   repo_slug: owner/repo-name
```
```ruby
# Access in code:
Rails.application.credentials.dig(:github, :token)
Rails.application.credentials.dig(:github, :repo_slug)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Explicit `PRAGMA journal_mode = WAL` in database.yml | Automatic via Rails adapter `configure_connection` | Rails 7.1 | No database.yml pragma changes needed; WAL is guaranteed |
| Separate cron daemon (whenever gem) | Solid Queue `recurring.yml` with Fugit syntax | Rails 8 / Solid Queue 1.x | Schedule lives in Rails app; no system-level cron |
| Sidekiq for background jobs | Solid Queue (already installed) | Rails 8 default stack | No Redis dependency; SQLite-backed; in-Puma operation supported |
| Chart.js v2 API (gridLines) | Chart.js v3+ API (grid) | Chart.js v3 (2021) | Old tutorials use `gridLines`; current API uses `grid` inside `scales.x/y` |

**Deprecated/outdated:**
- `gridLines` Chart.js option: replaced by `grid` in Chart.js v3+. Old Stack Overflow answers use the v2 API. Chartkick 5.x bundles Chart.js v4 (`Chart.bundle.js` in vendor/javascript).
- Octokit v8 and earlier used a different Faraday middleware stack. v9+ is the current API.

---

## Open Questions

1. **Star history depth on first deploy**
   - What we know: The snapshot approach starts accumulating from day one of deployment. Star/fork charts will be empty or near-empty for the first ~30 days.
   - What's unclear: Whether the user finds this acceptable or wants a one-time backfill of recent star history via the stargazers pagination endpoint.
   - Recommendation: Document the "Collecting data..." empty state in the UI. Defer any backfill option to a future enhancement. The user already agreed to the "Collecting data..." state.

2. **Stats endpoint behavior on a young repo**
   - What we know: `commit_activity_stats` and `contributors_stats` return 202 on first call and may return zero-filled arrays for recent weeks on a young or low-activity repo.
   - What's unclear: How to distinguish "no commits this week" (legitimately 0) from "stats not yet computed" (202 response).
   - Recommendation: Treat nil/empty response as unavailable (retry). Treat an array of all zeros as valid data (display as-is).

3. **Solid Queue in Puma vs separate bin/jobs process**
   - What we know: The deploy.yml has `SOLID_QUEUE_IN_PUMA: true`. The job server comment is commented out. The recurring scheduler runs inside the Puma process.
   - What's unclear: Whether the recurring scheduler activates in Puma mode or only when running `bin/jobs`.
   - Recommendation: Verify in staging that recurring jobs fire when running via `SOLID_QUEUE_IN_PUMA=true`. The Solid Queue README states the Puma plugin starts the scheduler. This should work, but confirmation is a deployment prerequisite.

4. **Search API rate limit for issue/PR counts**
   - What we know: Search API has a separate 30 req/min rate limit for authenticated users. One GithubMetricJob run makes 4 search API calls (open issues, closed issues, open PRs, merged PRs).
   - What's unclear: Whether closed_issues search (which scans all-time history) becomes slow for popular repos with thousands of closed issues.
   - Recommendation: Use `client.search_issues` with `total_count` only — do not paginate results. This returns the count in one call with no data transfer overhead.

---

## Sources

### Primary (HIGH confidence)
- [GitHub REST API - Repository endpoint](https://docs.github.com/en/rest/repos/repos#get-a-repository) — field names: stargazers_count, forks_count, open_issues_count
- [GitHub REST API - Statistics endpoints](https://docs.github.com/en/rest/metrics/statistics) — 202 behavior, commit_activity format, contributor stats
- [GitHub REST API - Starring endpoints](https://docs.github.com/en/rest/activity/starring) — stargazers with timestamps, Accept header
- [GitHub REST API - Issues endpoints](https://docs.github.com/en/rest/issues/issues#list-repository-issues) — state parameter, PR inclusion in results
- [GitHub REST API - Rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) — 5,000 req/hr authenticated, 60 req/hr unauthenticated
- [Octokit.rb RubyDoc - Client methods](https://octokit.github.io/octokit.rb/Octokit/Client.html) — method signatures: stargazers, forks, issues, pull_requests, commits, contributors, releases, stats
- [RubyGems - octokit 10.0.0](https://rubygems.org/gems/octokit/versions/10.0.0) — current version 10.0.0, released 2025-04-24
- [Chartkick homepage](https://chartkick.com/) — chart types, library options, colors, axes config
- [Solid Queue README](https://github.com/rails/solid_queue) — recurring.yml format, SOLID_QUEUE_IN_PUMA, Fugit schedule syntax
- [Rails 7.1 SQLite WAL blog — BigBinary](https://www.bigbinary.com/blog/rails-7-1-comes-with-an-optimized-default-sqlite3-adapter-connection-configuration) — WAL automatic since Rails 7.1

### Secondary (MEDIUM confidence)
- [Solid Queue practical guide 2025 — nsinenko.com](https://nsinenko.com/rails/background-jobs/performance/2025/10/07/solid-queue-rails-practical-guide/) — recurring.yml syntax examples, production notes
- [SQLite on Rails: optimal performance — fractaledmind.com](https://fractaledmind.com/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/) — WAL pragma details, confirmed automatic in Rails 7.1+
- [GitHub community discussion — separate issue/PR counts](https://github.com/orgs/community/discussions/102620) — open_issues_count includes PRs; workaround via Search API
- [Rails credentials best practices — DEV Community](https://dev.to/rna/stop-using-the-environment-variables-for-sensitive-keys-in-rails-4g2c) — credentials.yml.enc pattern

### Tertiary (LOW confidence — verify if used)
- Chart.js v3+ dark theme configuration: verified structure via Chart.js docs colors/styling pages, but specific hex values in examples are illustrative only

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all gems already in Gemfile.lock with exact versions
- GitHub API endpoints: HIGH — verified against official GitHub REST API docs
- Architecture: HIGH — standard Rails patterns, confirmed against official guides
- Chartkick/Chart.js dark theme: MEDIUM — library options structure verified; specific color values are illustrative
- Solid Queue recurring format: HIGH — verified against official README and corroborated by multiple 2025 sources
- WAL mode: HIGH — confirmed automatic since Rails 7.1 via multiple sources including the Rails PR

**Research date:** 2026-02-23
**Valid until:** 2026-05-23 (stable stack; re-verify octokit version if >60 days old)
