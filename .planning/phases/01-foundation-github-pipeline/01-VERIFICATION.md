---
phase: 01-foundation-github-pipeline
verified: 2026-02-23T00:00:00Z
status: human_needed
score: 13/13 must-haves verified
human_verification:
  - test: "Visit http://localhost:3000 and confirm dark theme renders correctly"
    expected: "Dark background (#020617), light text, vibrant chart colors; sticky nav visible at top; no login prompt"
    why_human: "Visual appearance and layout correctness cannot be verified programmatically"
  - test: "Scroll down and confirm sticky nav stays fixed at top with working section jump links"
    expected: "Nav bar remains pinned; clicking 'Stars & Forks', 'Activity', 'Issues & PRs', 'Releases' jumps to the correct section"
    why_human: "Scroll behavior and CSS position:fixed require a browser"
  - test: "Confirm empty state with no data in the database"
    expected: "Full-page 'Collecting data...' message with ~6 hour timing hint; no broken charts or errors"
    why_human: "Empty state appearance requires browser rendering"
  - test: "Seed test data and verify charts render"
    expected: "Stars area chart renders a line; contributor chart shows growth trend; release section shows 'X releases in last 30 days'"
    why_human: "Chartkick/Chart.js rendering requires a browser with JavaScript"
  - test: "Confirm page load speed is near-instant"
    expected: "Page loads in well under 3 seconds because all data is pre-fetched DB queries, no API calls in request path"
    why_human: "Load time perception requires a browser or load-testing tool"
---

# Phase 1: Foundation + GitHub Pipeline Verification Report

**Phase Goal:** Real GitHub data flows into the dashboard — time-series charts show actual star, fork, issue, and commit history
**Verified:** 2026-02-23
**Status:** human_needed — all automated checks pass; 5 items need browser verification
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | GitHubMetric model stores and queries any metric type with a date and numeric value | VERIFIED | `app/models/github_metric.rb` — 11 METRIC_TYPES constant, validations, `chart_data`/`latest_value` class methods, 3 scopes; `bin/rails runner` confirms `github_metrics` table name loads correctly |
| 2  | GithubClient wraps Octokit and raises typed errors (RateLimitError, AuthError, NotFoundError, StatsUnavailableError) | VERIFIED | `app/services/github_client.rb` — 4 typed inner error classes defined; all Octokit exceptions mapped in `repository`, `fetch_stats`, and `latest_release` methods |
| 3  | GitHub API credentials are loaded from Rails credentials or ENV, never hardcoded | VERIFIED | `credentials.dig(:github, :token) \|\| ENV["GITHUB_TOKEN"]` in `initialize`; `credentials.dig(:github, :repo_slug) \|\| ENV.fetch("GITHUB_REPO_SLUG", ...)` for REPO_SLUG; grep for hardcoded tokens returned no results |
| 4  | SQLite WAL mode is active on the primary database | VERIFIED | `bin/rails runner "PRAGMA journal_mode"` outputs `{"journal_mode"=>"wal"}` |
| 5  | GithubMetricJob fetches all 11 GitHub metric types and stores them as GitHubMetric rows | VERIFIED | `app/jobs/github_metric_job.rb` — 5 private record_* methods cover all 11 types: stars, forks, open/closed issues, open/merged/closed PRs, commit_frequency, contributor_count, latest_release_date, release_cadence; `GitHubMetric.find_or_create_by!` upserts in each |
| 6  | GithubMetricJob handles rate limit errors gracefully — individual metric failures do not prevent other metrics from saving | VERIFIED | `safe_call` wraps each GithubClient call and catches `RateLimitError`/`StatsUnavailableError` returning nil; top-level `rescue GithubClient::RateLimitError` catches job-wide rate limits without re-raising |
| 7  | DataRetentionJob deletes GitHubMetric records older than 30 days | VERIFIED | `app/jobs/data_retention_job.rb` — `GitHubMetric.where("recorded_on < ?", cutoff).delete_all` where `cutoff = 30.days.ago.to_date` |
| 8  | Both jobs are scheduled in recurring.yml — GithubMetricJob every 6 hours, DataRetentionJob daily at 3am | VERIFIED | `config/recurring.yml` contains `github_metrics_fetch: class: GithubMetricJob, schedule: every 6 hours` and `data_retention_prune: class: DataRetentionJob, schedule: every day at 3am` |
| 9  | Dashboard shows stars, forks, issues, PRs, commit frequency, contributor count, and release info as charts/cards | VERIFIED | `app/views/dashboard/index.html.erb` — 4 sections render all metric types; area_chart for stars/forks, bar_chart for commits, line_chart for contributor trend, stat cards for issues/PRs, release card with cadence |
| 10 | Dashboard controller only queries the database — no API calls in the request path | VERIFIED | `app/controllers/dashboard_controller.rb` — 13 `GitHubMetric.chart_data` and `GitHubMetric.latest_value` calls only; no GithubClient instantiation |
| 11 | Empty state shows 'Collecting data...' when no metrics exist | VERIFIED | View checks `!@has_data` for full-page empty state; each chart card checks `metric_empty?(data)` for per-chart empty state |
| 12 | Dashboard is publicly accessible with no login prompt | VERIFIED | `ApplicationController` has no `before_action` for auth; `config/routes.rb` routes root to `dashboard#index`; no Devise or auth gem installed |
| 13 | All tests pass | VERIFIED | `bundle exec rails test` — 33 runs, 64 assertions, 0 failures, 0 errors, 0 skips |

**Score:** 13/13 truths verified (automated)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/models/github_metric.rb` | GitHubMetric model with metric_type, value, recorded_on; chart_data and latest_value | VERIFIED | 25 lines; class GitHubMetric, METRIC_TYPES, 3 validations, 3 scopes, 2 class methods |
| `db/migrate/20260224000357_create_github_metrics.rb` | Migration creating github_metrics table with unique index | VERIFIED | `create_table :github_metrics` with NOT NULL constraints on all 3 columns, `add_index [:metric_type, :recorded_on], unique: true` |
| `app/services/github_client.rb` | Octokit wrapper with typed errors and stats retry logic | VERIFIED | 79 lines; class GithubClient with 4 typed error classes, 8 API methods, private `fetch_stats` retry loop |
| `Gemfile` | octokit dependency | VERIFIED | `gem "octokit", "~> 10.0"` at line 47; Gemfile.lock shows `octokit (10.0.0)` |
| `app/jobs/github_metric_job.rb` | Background job fetching all GitHub metrics with upserts | VERIFIED | 95 lines; class GithubMetricJob with all 5 record_* methods, `upsert`, `safe_call` |
| `app/jobs/data_retention_job.rb` | Background job pruning old GitHubMetric records | VERIFIED | 11 lines; class DataRetentionJob, RETENTION_DAYS = 30, `delete_all` prune |
| `config/recurring.yml` | Solid Queue schedule with github_metrics_fetch and data_retention_prune | VERIFIED | Both entries present under `production:` with correct Fugit schedules |
| `app/controllers/dashboard_controller.rb` | Controller querying GitHubMetric for all chart data | VERIFIED | 29 lines; 13 GitHubMetric queries covering all metrics and instance variables |
| `app/views/dashboard/index.html.erb` | Full dashboard view with charts, sections, nav, empty states | VERIFIED | 228 lines; sticky nav, 4 sections, area_chart/bar_chart/line_chart, stat cards, release card, empty states |
| `app/assets/stylesheets/application.css` | Dark theme CSS with sticky nav, grid layout, card styles | VERIFIED | 402 lines; background #020617, position:fixed nav, 2-column responsive grid at 1024px, all card variants |
| `config/initializers/chartkick.rb` | Chartkick global dark theme options | VERIFIED | 19 lines; `Chartkick.options` with 6 colors, dark tooltip config, slate grid lines |
| `app/helpers/dashboard_helper.rb` | Helper methods for formatting numbers, dates, empty state detection | VERIFIED | 37 lines; all 5 helpers: format_number, format_date, metric_empty?, jd_to_date, time_ago_or_never |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/services/github_client.rb` | `Rails.application.credentials` | `credentials.dig(:github, :token)` with ENV fallback | WIRED | Line 12: `credentials.dig(:github, :token) \|\| ENV["GITHUB_TOKEN"]` |
| `app/models/github_metric.rb` | `db/migrate/20260224000357_create_github_metrics.rb` | ActiveRecord schema | WIRED | `bin/rails db:migrate:status` shows `up`; `GitHubMetric.table_name` returns `github_metrics` |
| `app/jobs/github_metric_job.rb` | `app/services/github_client.rb` | `GithubClient.new` in perform | WIRED | Line 5: `client = GithubClient.new` |
| `app/jobs/github_metric_job.rb` | `app/models/github_metric.rb` | `GitHubMetric.find_or_create_by!` upserts | WIRED | Lines 82-84: `GitHubMetric.find_or_create_by!(metric_type: ..., recorded_on: ...)` |
| `app/jobs/data_retention_job.rb` | `app/models/github_metric.rb` | `GitHubMetric.where(...).delete_all` | WIRED | Line 8: `GitHubMetric.where("recorded_on < ?", cutoff).delete_all` |
| `config/recurring.yml` | `app/jobs/github_metric_job.rb` | `class: GithubMetricJob` schedule entry | WIRED | Line 18: `class: GithubMetricJob` under `github_metrics_fetch` |
| `app/controllers/dashboard_controller.rb` | `app/models/github_metric.rb` | `GitHubMetric.chart_data` and `latest_value` queries | WIRED | Lines 4-28: 13 calls to `GitHubMetric.chart_data(...)` and `GitHubMetric.latest_value(...)` |
| `app/views/dashboard/index.html.erb` | `app/controllers/dashboard_controller.rb` | Instance variables passed to view | WIRED | View references `@stars_data`, `@forks_data`, `@commit_data`, `@contributor_data`, `@release_cadence`, `@has_data`, etc. |

---

### Requirements Coverage

All 17 requirement IDs declared across the 3 plans for this phase are accounted for:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| INFRA-01 | 01-01 | SQLite WAL mode enabled | SATISFIED | `PRAGMA journal_mode` outputs `wal` at runtime |
| INFRA-02 | 01-01 | Shared rate-limit-aware HTTP client with typed errors | SATISFIED | GithubClient with RateLimitError, AuthError, NotFoundError, StatsUnavailableError |
| INFRA-03 | 01-01 | API credentials in Rails credentials or ENV, never hardcoded | SATISFIED | `credentials.dig(:github, :token) \|\| ENV["GITHUB_TOKEN"]`; no hardcoded tokens found |
| INFRA-04 | 01-02 | Solid Queue recurring job schedule configured | SATISFIED | `config/recurring.yml` with `github_metrics_fetch` and `data_retention_prune` entries |
| INFRA-05 | 01-02 | Data retention job prunes records older than 30 days daily | SATISFIED | DataRetentionJob with `schedule: every day at 3am` in recurring.yml |
| GH-01 | 01-03 | Star count over time as line chart (30-day rolling) | SATISFIED | `area_chart @stars_data` in view; `@stars_data = GitHubMetric.chart_data("stars")` in controller |
| GH-02 | 01-03 | Fork count over time as line chart (30-day rolling) | SATISFIED | `area_chart @forks_data` in view; `@forks_data = GitHubMetric.chart_data("forks")` in controller |
| GH-03 | 01-03 | Open vs. closed issue counts | SATISFIED | Stat cards rendering `@open_issues` and `@closed_issues` in Issues & PRs section |
| GH-04 | 01-03 | PR activity (open/merged/closed) | SATISFIED | Three PR stat cards in Issues & PRs section |
| GH-05 | 01-03 | Commit frequency per day | SATISFIED | `bar_chart @commit_data` in Activity section |
| GH-06 | 01-03 | Contributor count and new contributor growth | SATISFIED | Headline `@contributor_count` number + `line_chart @contributor_data` (30-day growth trend) |
| GH-07 | 01-03 | Latest release info and release cadence | SATISFIED | Release card shows `jd_to_date(@latest_release_jd)` date + `@release_cadence.to_i releases in last 30 days` |
| GH-08 | 01-02 | Background job fetches GitHub metrics every 6 hours | SATISFIED | GithubMetricJob with `schedule: every 6 hours` in recurring.yml |
| GH-09 | 01-01 | GitHub data stored in GitHubMetric (metric_type + value + recorded_on, unique index) | SATISFIED | Migration creates table with unique index on [metric_type, recorded_on] |
| DASH-02 | 01-03 | Time-series charts via Chartkick/Chart.js with real data | SATISFIED | Chartkick helpers (area_chart, bar_chart, line_chart) wired to real GitHubMetric.chart_data queries |
| DASH-05 | 01-03 | Page loads under 3 seconds | NEEDS HUMAN | Controller has no API calls — only 13 local DB queries — but actual load time needs browser measurement |
| DASH-06 | 01-03 | Public-facing, no authentication required | SATISFIED | ApplicationController has no auth before_action; no Devise installed; root route public |

**No orphaned requirements.** REQUIREMENTS.md maps all 17 IDs to Phase 1; all 17 appear in plan frontmatter.

---

### Anti-Patterns Found

No anti-patterns detected. Grep across all 8 key files found:

- Zero `TODO`, `FIXME`, `XXX`, `HACK`, or `placeholder` comments
- Zero empty handler patterns (`return null`, `return {}`, `=> {}`)
- Zero hardcoded API tokens or credentials
- No stub implementations (all methods have substantive logic)

---

### Human Verification Required

The following items require a browser to verify. Note that the user **already visually approved the dashboard** during Plan 01-03 Task 3 (checkpoint:human-verify gate marked "approved"). These items are listed for completeness and confirmability, not as blocking gaps.

#### 1. Dark Theme Visual Appearance

**Test:** Start `bin/rails server` and visit `http://localhost:3000`
**Expected:** Dark background (#020617), light text (#e2e8f0), vibrant chart accent colors, sticky nav at top, no login prompt
**Why human:** CSS rendering and visual correctness require a browser

#### 2. Sticky Navigation Behavior

**Test:** Scroll down on the dashboard; click section jump links in the nav
**Expected:** Nav bar remains fixed at top; clicking "Stars & Forks", "Activity", "Issues & PRs", "Releases" scrolls to the correct section
**Why human:** CSS `position: fixed` and smooth scroll behavior require a browser

#### 3. Empty State Rendering

**Test:** With no GitHubMetric records, visit `http://localhost:3000`
**Expected:** Full-page "Collecting data..." message with clock icon and "approximately 6 hours after deployment" hint; no broken charts
**Why human:** Full-page empty state appearance requires browser rendering

#### 4. Chart Rendering with Real Data

**Test:** Seed test data and refresh the dashboard:
```
bin/rails runner "
  5.times { |i| GitHubMetric.create!(metric_type: 'stars', value: 100 + i*10, recorded_on: i.days.ago) }
  5.times { |i| GitHubMetric.create!(metric_type: 'contributor_count', value: 20 + i, recorded_on: i.days.ago) }
  GitHubMetric.create!(metric_type: 'release_cadence', value: 3, recorded_on: Date.today)
"
```
**Expected:** Stars section shows an area chart line; Activity section shows contributor growth trend line chart; Release section shows "3 releases in last 30 days"
**Why human:** Chartkick/Chart.js rendering and chart appearance require a browser with JavaScript

#### 5. Page Load Speed (DASH-05)

**Test:** Open browser DevTools Network tab and reload `http://localhost:3000`
**Expected:** Page load completes in under 3 seconds; no external API requests visible in the network waterfall
**Why human:** Load time measurement requires a browser

---

### Gaps Summary

No gaps. All 13 observable truths are verified, all 12 artifacts exist and are substantive, all 8 key links are wired. The `human_needed` status reflects 5 browser-only verification items — notably, the user already approved the dashboard visually during Plan 01-03's blocking human-verify checkpoint. Automated evidence (33 passing tests, WAL mode confirmed, correct SQL schema, no hardcoded credentials, full controller-to-view wiring) establishes high confidence in goal achievement.

---

_Verified: 2026-02-23_
_Verifier: Claude (gsd-verifier)_
