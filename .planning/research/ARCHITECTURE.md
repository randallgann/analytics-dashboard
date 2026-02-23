# Architecture Patterns: GitHub Analytics + Social Media Tracking

**Domain:** Open-source project analytics and social tracking dashboard
**Researched:** 2026-02-23
**Confidence Note:** Research based on established Rails patterns and codebase analysis. External web search unavailable in this session. Architecture is based on HIGH-confidence Rails/ActiveJob patterns and MEDIUM-confidence API integration conventions.

---

## Recommended Architecture

### Overview

The system extends the existing Rails MVC monolith with three new layers:

1. **API Client layer** — thin wrappers around GitHub, Reddit, Hacker News, YouTube, and X/Twitter APIs
2. **Data Ingest layer** — Solid Queue background jobs that call clients, normalize responses, and persist records
3. **Aggregation/Query layer** — model scopes and helper objects that prepare time-series and feed data for controllers

The existing controller → view → Chartkick path remains unchanged. Controllers query the aggregation layer instead of the placeholder static data they currently hold.

```
External APIs
     │
     ▼
[API Clients]          lib/api_clients/github_client.rb
(lib/api_clients/)     lib/api_clients/reddit_client.rb
                        lib/api_clients/hacker_news_client.rb
                        lib/api_clients/youtube_client.rb
                        lib/api_clients/twitter_client.rb
     │
     ▼
[Ingest Jobs]          app/jobs/fetch_github_metrics_job.rb
(app/jobs/)            app/jobs/fetch_social_posts_job.rb
                        app/jobs/prune_old_records_job.rb
                        (scheduled via Solid Queue recurring config)
     │
     ▼
[ActiveRecord Models]  app/models/github_metric.rb
(app/models/)          app/models/social_post.rb
                        (SQLite3 via primary database)
     │
     ▼
[Aggregation Layer]    app/models/concerns/github_metrics_aggregator.rb
(model scopes +        app/models/concerns/social_feed_builder.rb
 query objects)
     │
     ▼
[Controllers]          app/controllers/dashboard_controller.rb
                        (queries aggregation layer, passes data to views)
     │
     ▼
[Views + Chartkick]    app/views/dashboard/index.html.erb
                        (time-series charts, social post cards)
```

---

## Component Boundaries

| Component | Responsibility | Accepts | Returns | Communicates With |
|-----------|---------------|---------|---------|-------------------|
| **API Clients** (`lib/api_clients/`) | Make HTTP calls to external APIs, handle auth headers, pagination, rate-limit errors | Config (token, query params) | Raw normalized Hash | Called by Ingest Jobs only |
| **Ingest Jobs** (`app/jobs/`) | Orchestrate fetch cycles: call client, upsert records, handle errors, schedule next run | Triggered by Solid Queue scheduler | Nothing (side effects only) | API Clients, ActiveRecord Models |
| **ActiveRecord Models** (`app/models/`) | Persist metric snapshots and social posts, enforce data shape, provide query scopes | Job writes, controller reads | ActiveRecord::Relation | Ingest Jobs (write), Aggregation layer (read) |
| **Aggregation Layer** (model scopes / query objects) | Produce chart-ready time-series arrays and ranked social feed lists within 30-day window | ActiveRecord query parameters | Ruby arrays/hashes formatted for Chartkick | Controllers |
| **Dashboard Controller** (`app/controllers/dashboard_controller.rb`) | Fetch aggregated data, assign to instance variables, render view | HTTP GET request | HTML response | Aggregation layer, Views |
| **Views + Chartkick** (`app/views/dashboard/`) | Render time-series charts and social post card lists | Instance variables from controller | HTML | Browser (no JS framework — existing Chartkick/Chart.js) |
| **Pruning Job** (`app/jobs/prune_old_records_job.rb`) | Delete records older than 30 days to bound SQLite growth | Solid Queue scheduler | Nothing | ActiveRecord Models |

---

## Data Flow

### Ingest Path (background, scheduled)

```
Solid Queue Scheduler
  → FetchGitHubMetricsJob#perform
      → GitHubClient.fetch_repo_stats(token:, repo: "openclaw/openclaw")
          → HTTPS GET api.github.com/repos/:owner/:repo
          → HTTPS GET api.github.com/repos/:owner/:repo/stargazers (paginated)
          → HTTPS GET api.github.com/repos/:owner/:repo/contributors
          → HTTPS GET api.github.com/repos/:owner/:repo/commits
      → GitHubMetric.upsert_all([...normalized records...], unique_by: [:metric_type, :recorded_on])
          → SQLite3 primary database

  → FetchSocialPostsJob#perform
      → RedditClient.search(query: "openclaw", subreddits: ["programming", "opensource"])
      → HackerNewsClient.search(query: "openclaw")
      → YouTubeClient.search(query: "openclaw")
      → TwitterClient.search(query: "openclaw")       # if API access available
      → SocialPost.upsert_all([...normalized records...], unique_by: [:platform, :external_id])
          → SQLite3 primary database

  → PruneOldRecordsJob#perform
      → GitHubMetric.where("recorded_on < ?", 30.days.ago).delete_all
      → SocialPost.where("published_at < ?", 30.days.ago).delete_all
```

### Read Path (HTTP request)

```
Browser GET /
  → DashboardController#index
      → GitHubMetric.stars_over_time(days: 30)       → [[date, count], ...]
      → GitHubMetric.forks_over_time(days: 30)       → [[date, count], ...]
      → GitHubMetric.issues_activity(days: 30)        → {open: [...], closed: [...]}
      → GitHubMetric.contributor_growth(days: 30)    → [[date, count], ...]
      → SocialPost.trending_feed(platform: :reddit)  → [SocialPost, ...]
      → SocialPost.trending_feed(platform: :hn)      → [SocialPost, ...]
      → SocialPost.trending_feed(platform: :youtube) → [SocialPost, ...]
  → render dashboard/index.html.erb
      → <%= line_chart @stars_over_time %>             (Chartkick → Chart.js)
      → <% @reddit_posts.each do |post| %>             (card partial)
```

---

## Key Abstractions

### API Client Pattern (lib/api_clients/)

Each client is a plain Ruby class (not a model or job) that:
- Takes credentials from `Rails.application.credentials` or `ENV`
- Makes HTTP calls using `Net::HTTP` or the `faraday` gem
- Returns normalized Ruby hashes — no ActiveRecord coupling
- Raises typed errors (`RateLimitError`, `AuthError`, `NotFoundError`) that jobs rescue

**Why `lib/` not `app/`:** API clients are infrastructure, not domain objects. Rails auto-loads `lib/` when configured (`config.autoload_lib`). Keeping them out of `app/` makes the domain boundary explicit.

```ruby
# lib/api_clients/github_client.rb
class ApiClients::GitHubClient
  BASE_URL = "https://api.github.com"

  def initialize(token: Rails.application.credentials.dig(:github, :token))
    @token = token
  end

  def repo_stats(owner:, repo:)
    get("/repos/#{owner}/#{repo}")
  end

  def stargazers_per_day(owner:, repo:, since:)
    # paginate /repos/:owner/:repo/stargazers with Accept: application/vnd.github.star+json
    # return [{starred_at: Date, count: Integer}, ...]
  end

  private

  def get(path, params: {})
    # Net::HTTP or Faraday call with Authorization: Bearer @token
    # raise typed errors on 403, 429, 404
  end
end
```

### ActiveRecord Models

Two primary models suffice for v1:

**`GitHubMetric`** — one row per metric type per day
```
Table: github_metrics
  id            integer  primary key
  metric_type   string   (e.g., "stars", "forks", "open_issues", "contributors")
  value         integer  (snapshot value)
  recorded_on   date     (the day this snapshot represents)
  created_at    datetime

  Unique index: [metric_type, recorded_on]
```

**`SocialPost`** — one row per post per platform
```
Table: social_posts
  id            integer  primary key
  platform      string   ("reddit", "hacker_news", "youtube", "twitter")
  external_id   string   (platform's own ID — prevents duplicates)
  title         string
  url           string
  author        string
  score         integer  (upvotes / likes / views — platform-specific)
  comment_count integer
  published_at  datetime
  fetched_at    datetime
  created_at    datetime

  Unique index: [platform, external_id]
  Index: [platform, published_at]   -- for feed queries
  Index: [published_at]             -- for pruning
```

**Why two models instead of one per source:** The social posts all have the same shape (title, url, author, score, published_at). A single polymorphic table with a `platform` column eliminates migration sprawl when adding a new source. GitHub metrics are structurally different (numeric time-series) so they stay separate.

### Aggregation Layer (model scopes)

Aggregation lives in model scopes and concern modules — not in controllers. Controllers should be thin.

```ruby
# app/models/github_metric.rb
class GitHubMetric < ApplicationRecord
  scope :within_30_days, -> { where(recorded_on: 30.days.ago.to_date..) }

  def self.stars_over_time(days: 30)
    where(metric_type: "stars")
      .where(recorded_on: days.days.ago.to_date..)
      .order(:recorded_on)
      .pluck(:recorded_on, :value)
  end
end
```

```ruby
# app/models/social_post.rb
class SocialPost < ApplicationRecord
  scope :trending_feed, ->(platform:, limit: 20) {
    where(platform: platform)
      .where(published_at: 30.days.ago..)
      .order(score: :desc, published_at: :desc)
      .limit(limit)
  }
end
```

### Job Organization

Three jobs, distinct responsibilities:

| Job | Schedule | Responsibility |
|-----|----------|---------------|
| `FetchGitHubMetricsJob` | Every 6 hours | Fetch repo stats, stargazers, contributors, commits, issues/PRs |
| `FetchSocialPostsJob` | Every 2 hours | Search Reddit, HN, YouTube, Twitter for "openclaw" mentions |
| `PruneOldRecordsJob` | Daily (midnight) | Delete records older than 30 days from both tables |

**Solid Queue recurring schedule** (configured in `config/recurring.yml`):

```yaml
# config/recurring.yml
fetch_github_metrics:
  class: FetchGitHubMetricsJob
  schedule: every 6 hours
  queue: data_ingest

fetch_social_posts:
  class: FetchSocialPostsJob
  schedule: every 2 hours
  queue: data_ingest

prune_old_records:
  class: PruneOldRecordsJob
  schedule: every day at midnight
  queue: maintenance
```

### Error Handling in Jobs

Jobs must be resilient to API failures without crashing the queue:

```ruby
class FetchGitHubMetricsJob < ApplicationJob
  queue_as :data_ingest
  retry_on ApiClients::RateLimitError, wait: :polynomially_longer, attempts: 3
  discard_on ApiClients::AuthError  # bad token — retrying won't help

  def perform
    client = ApiClients::GitHubClient.new
    stats = client.repo_stats(owner: "openclaw", repo: "openclaw")
    GitHubMetric.upsert_all(normalize(stats), unique_by: [:metric_type, :recorded_on])
  rescue ApiClients::NotFoundError => e
    Rails.logger.error("GitHub repo not found: #{e.message}")
    # don't re-raise — let job succeed so queue doesn't stall
  end
end
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Live API Calls in Controllers
Controllers only read from the local SQLite database. All API calls happen in background jobs.

### Anti-Pattern 2: Fat Jobs That Do Everything
One job per data source. Jobs are independent, schedulable, and testable individually.

### Anti-Pattern 3: Denormalized Per-Platform Models
Single `SocialPost` model with a `platform` column. One query for all feeds.

### Anti-Pattern 4: Storing Raw API Responses
Normalize API responses to explicit columns at ingest time.

### Anti-Pattern 5: Chartkick Data Built in Views
Controllers compute and assign chart data to named instance variables. Views receive pre-built arrays.

---

## Suggested Build Order (Phase Dependencies)

```
1. Database schema (models + migrations)
        ↓
2. API clients (lib/api_clients/ — testable in isolation without jobs)
        ↓
3. Ingest jobs (depend on clients and models)
        ↓
4. Solid Queue scheduler config (depends on jobs existing)
        ↓
5. Aggregation queries (model scopes — depend on data existing)
        ↓
6. Controller wiring (replaces static data with aggregation queries)
        ↓
7. View updates (charts use real data, social post cards added)
```

**Why this order:**
- Schema must exist before models can write or read
- API clients are pure Ruby — build and test them before wiring to jobs
- Jobs need both clients (to fetch) and models (to persist)
- Aggregation queries need data in the DB to validate correctness
- Controllers should not be touched until the data layer is proven
- Views are last because they depend on controllers having real data

**One source at a time:** Build GitHub metrics end-to-end (schema → client → job → queries → controller → view) before starting social posts. This gives a working, demo-able vertical slice faster than building all clients first.

---

## File Map: Where New Code Lives

```
analytics-dashboard/
├── lib/
│   └── api_clients/
│       ├── github_client.rb          (NEW) GitHub REST API wrapper
│       ├── reddit_client.rb          (NEW) Reddit search API wrapper
│       ├── hacker_news_client.rb     (NEW) Algolia HN search API wrapper
│       ├── youtube_client.rb         (NEW) YouTube Data API v3 wrapper
│       └── twitter_client.rb         (NEW) X/Twitter API v2 wrapper
│
├── app/
│   ├── models/
│   │   ├── github_metric.rb          (NEW) Time-series metric snapshots
│   │   └── social_post.rb            (NEW) Normalized social posts across platforms
│   │
│   ├── jobs/
│   │   ├── application_job.rb        (EXISTS — base class)
│   │   ├── fetch_github_metrics_job.rb  (NEW)
│   │   ├── fetch_social_posts_job.rb    (NEW)
│   │   └── prune_old_records_job.rb     (NEW)
│   │
│   ├── controllers/
│   │   └── dashboard_controller.rb   (MODIFY — add real data queries)
│   │
│   └── views/
│       └── dashboard/
│           ├── index.html.erb         (MODIFY — add real charts + social feeds)
│           └── _social_post.html.erb  (NEW) — social post card partial
│
├── db/
│   └── migrate/
│       ├── YYYYMMDD_create_github_metrics.rb   (NEW)
│       └── YYYYMMDD_create_social_posts.rb     (NEW)
│
└── config/
    └── recurring.yml                 (NEW) — Solid Queue scheduler config
```

---

## Sources

- Rails 8.1 ActiveJob documentation — HIGH confidence (well-established patterns)
- Solid Queue recurring job configuration — MEDIUM confidence (verify `recurring.yml` format against current Solid Queue docs before implementation)
- SQLite3 `upsert_all` with `unique_by` — HIGH confidence (Rails 6+ feature, stable API)
- GitHub REST API v3 endpoint structure — HIGH confidence (stable, documented)
- Reddit API, HN Algolia API, YouTube Data API v3 — MEDIUM confidence (verify current authentication requirements and rate limits before implementation)
- X/Twitter API — LOW confidence (access tier and endpoint availability change frequently; verify current API plan requirements)
