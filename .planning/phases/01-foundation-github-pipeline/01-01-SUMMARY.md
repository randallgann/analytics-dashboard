---
phase: 01-foundation-github-pipeline
plan: 01
subsystem: database
tags: [ruby, rails, octokit, sqlite, activerecord, zeitwerk]

# Dependency graph
requires: []
provides:
  - GitHubMetric ActiveRecord model with schema, validations, scopes (for_metric, last_30_days, ordered), and class methods (chart_data, latest_value)
  - github_metrics SQLite table with unique index on [metric_type, recorded_on]
  - GithubClient service wrapping Octokit with typed errors and stats retry logic
  - Octokit 10.0 gem installed and locked
  - SQLite WAL mode confirmed active
affects:
  - 01-02  # scheduler/sync jobs depend on GithubClient and GitHubMetric
  - 01-03  # dashboard views use GitHubMetric.chart_data and latest_value
  - all subsequent phases  # every plan that queries GitHub data goes through these two classes

# Tech tracking
tech-stack:
  added: [octokit 10.0]
  patterns:
    - "Typed service errors: wrap Octokit exceptions in domain-specific error classes (AuthError, RateLimitError, NotFoundError, StatsUnavailableError)"
    - "Stats retry: exponential backoff loop for GitHub 202 endpoints (fetch_stats private method)"
    - "Credential loading: Rails.application.credentials.dig(:github, :token) with ENV fallback, never hardcoded"
    - "Zeitwerk inflection: github_metric.rb -> GitHubMetric via al.inflector.inflect; explicit self.table_name for non-standard mapping"

key-files:
  created:
    - app/models/github_metric.rb
    - app/services/github_client.rb
    - db/migrate/20260224000357_create_github_metrics.rb
    - db/schema.rb
    - test/models/github_metric_test.rb
    - test/services/github_client_test.rb
    - test/fixtures/github_metrics.yml
  modified:
    - Gemfile
    - Gemfile.lock
    - config/application.rb

key-decisions:
  - "Named model file github_metric.rb (not git_hub_metric.rb) — added Zeitwerk inflector in config/application.rb and explicit self.table_name = 'github_metrics' to maintain plan-specified naming"
  - "Used Search API (is:issue, is:pr) for issue/PR counts, not repository.open_issues_count, to avoid PR contamination in issue counts"
  - "Ruby 3.3.6 installed via ruby-install with --enable-shared flag since the static build cannot compile native extensions (bigdecimal, sqlite3)"
  - "Minitest 6.0.1 (bundled with Rails 8.1) has no Mock class — used define_singleton_method + FastGithubClient subclass for test doubles instead"

patterns-established:
  - "Typed errors pattern: All external API calls in services/ raise domain errors, never raw library exceptions"
  - "Stats retry pattern: Private fetch_stats with exponential backoff is the standard for GitHub stats endpoints"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03, GH-09]

# Metrics
duration: 16min
completed: 2026-02-23
---

# Phase 1 Plan 1: Foundation GitHub Pipeline Summary

**Octokit gem installed, GitHubMetric model with chart_data/latest_value scopes, and GithubClient service with typed errors and exponential-backoff retry for GitHub stats 202 responses**

## Performance

- **Duration:** 16 min
- **Started:** 2026-02-23T23:54:26Z
- **Completed:** 2026-02-23T00:10:26Z
- **Tasks:** 2 of 2
- **Files modified:** 10

## Accomplishments
- Installed Octokit ~> 10.0 and configured Ruby 3.3.6 with shared library support for native gem compilation
- GitHubMetric model at `github_metric.rb` with METRIC_TYPES constant, presence/inclusion/uniqueness validations, three scopes, and chart_data/latest_value class methods
- SQLite migration creating `github_metrics` table with unique index on [metric_type, recorded_on] — WAL mode confirmed active
- GithubClient service with 4 typed error classes, 8 API wrapper methods using Search API for issue/PR counts, and private fetch_stats retry loop (max 3 retries, 2^n backoff)
- 11 tests passing across model and service layers

## Task Commits

Each task was committed atomically:

1. **Task 1: Install Octokit, create GitHubMetric model and migration, verify WAL** - `afe0379` (feat)
2. **Task 2: Create GithubClient service with typed errors and stats retry** - `41633c7` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `app/models/github_metric.rb` - GitHubMetric model with validations, scopes, chart_data, latest_value
- `app/services/github_client.rb` - Octokit wrapper with typed errors and stats retry
- `db/migrate/20260224000357_create_github_metrics.rb` - Migration with constraints and unique index
- `db/schema.rb` - Auto-generated schema reflecting migration
- `test/models/github_metric_test.rb` - 6 model tests (valid save, uniqueness, chart_data, latest_value, nil, invalid type)
- `test/services/github_client_test.rb` - 5 service tests (init, AuthError, RateLimitError, retry, latest_release nil)
- `test/fixtures/github_metrics.yml` - Static date fixtures to avoid unique constraint conflicts
- `Gemfile` - Added octokit ~> 10.0
- `Gemfile.lock` - Updated with octokit 10.0.0 and dependencies
- `config/application.rb` - Zeitwerk inflection for github_metric.rb -> GitHubMetric

## Decisions Made
- **Zeitwerk inflection required**: Rails auto-underscores `GitHubMetric` to `git_hub_metric.rb`, not `github_metric.rb`. Added `al.inflector.inflect("github_metric" => "GitHubMetric")` in `config/application.rb` and set `self.table_name = "github_metrics"` explicitly in the model to satisfy the plan's artifact path requirement.
- **Search API for issue/PR counts**: The repository `open_issues_count` field includes PRs. Using `search_issues("is:issue is:open")` gives accurate issue-only counts.
- **Ruby 3.3.6 with --enable-shared**: ruby-install defaults to static build, which cannot compile native extensions like bigdecimal and sqlite3. Had to rebuild with `--enable-shared` flag.
- **No Minitest::Mock in Minitest 6**: Rails 8.1 ships minitest 6.0.1 which removed Mock. Used `define_singleton_method` for one-off stubs and a `FastGithubClient < GithubClient` subclass to skip sleep delays.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Zeitwerk naming conflict for GitHubMetric**
- **Found during:** Task 1 (model creation)
- **Issue:** Rails generator created `git_hub_metric.rb` (correct for Zeitwerk), but the plan requires `github_metric.rb`. After creating the file as `github_metric.rb`, `GitHubMetric` was uninitialized constant at runtime.
- **Fix:** Added Zeitwerk inflector config in `config/application.rb` and `self.table_name = "github_metrics"` in the model
- **Files modified:** config/application.rb, app/models/github_metric.rb
- **Verification:** `bin/rails runner "puts GitHubMetric.table_name"` outputs `github_metrics`
- **Committed in:** afe0379 (Task 1 commit)

**2. [Rule 3 - Blocking] Ruby 3.3.6 not installed on system**
- **Found during:** Task 1 (bundle install)
- **Issue:** System only had Ruby 2.6 (macOS), project requires 3.3.6. Homebrew was broken (bootsnap version mismatch). ruby-install default is static build (no native extensions).
- **Fix:** Fixed Homebrew bootsnap conflict, installed ruby-install, built Ruby 3.3.6 with `--enable-shared`
- **Files modified:** None (system-level setup)
- **Verification:** `ruby --version` outputs 3.3.6; `bundle install` succeeds
- **Committed in:** afe0379 (prerequisite for Task 1)

**3. [Rule 1 - Bug] Test fixture timestamp constraint failure**
- **Found during:** Task 1 (model tests)
- **Issue:** Initial fixtures used ERB dynamic dates which caused NOT NULL violations on `created_at`. Fixed to static timestamps, then UNIQUE constraint fired between fixture and test data.
- **Fix:** Changed fixtures to static hardcoded past dates (2025-01-15), used different metric_types in tests vs fixtures
- **Files modified:** test/fixtures/github_metrics.yml, test/models/github_metric_test.rb
- **Verification:** 6 model tests pass with `0 failures, 0 errors`
- **Committed in:** afe0379 (Task 1 commit)

**4. [Rule 3 - Blocking] Minitest::Mock unavailable in Minitest 6.0.1**
- **Found during:** Task 2 (service tests)
- **Issue:** Rails 8.1 ships minitest 6.0.1 which has no Mock class. Initial test used `Minitest::Mock.new` which raised `NameError`.
- **Fix:** Replaced with `define_singleton_method` for stubs and `FastGithubClient < GithubClient` subclass to override `sleep`
- **Files modified:** test/services/github_client_test.rb
- **Verification:** 5 service tests pass with `0 failures, 0 errors`
- **Committed in:** 41633c7 (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (2 blocking, 1 bug, 1 blocking)
**Impact on plan:** All fixes necessary for the implementation to work on this machine and testing environment. No scope creep. Artifacts match plan specification exactly.

## Issues Encountered
- Homebrew broken (bootsnap 1.19.0 vs 1.21.1 conflict) — fixed by removing stale bootsnap-1.19.0 directory
- `bin/rails runner "puts X"` fails with single quotes in zsh due to shell interpretation — used double quotes throughout

## User Setup Required

GitHub API credentials are needed for the GithubClient to make authenticated requests (5,000 req/hr with PAT vs 60 without):

1. Go to GitHub Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens
2. Generate new token with public_repo read access
3. Run: `EDITOR='nano' bin/rails credentials:edit`
4. Add:
   ```yaml
   github:
     token: ghp_your_token_here
     repo_slug: owner/repo-name
   ```
5. Alternatively, set `GITHUB_TOKEN` and `GITHUB_REPO_SLUG` environment variables

## Next Phase Readiness
- GitHubMetric model and GithubClient are ready for sync job implementation (Plan 01-02)
- All tests passing, WAL mode confirmed, octokit installed
- Credentials need to be set before any actual GitHub API calls will succeed

## Self-Check: PASSED

All created files exist and all task commits verified present in git log.

| Check | Result |
|-------|--------|
| app/models/github_metric.rb | FOUND |
| app/services/github_client.rb | FOUND |
| db/migrate/20260224000357_create_github_metrics.rb | FOUND |
| test/models/github_metric_test.rb | FOUND |
| test/services/github_client_test.rb | FOUND |
| Commit afe0379 (Task 1) | FOUND |
| Commit 41633c7 (Task 2) | FOUND |

---
*Phase: 01-foundation-github-pipeline*
*Completed: 2026-02-23*
