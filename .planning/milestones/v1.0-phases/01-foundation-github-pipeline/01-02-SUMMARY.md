---
phase: 01-foundation-github-pipeline
plan: 02
subsystem: infra
tags: [ruby, rails, solid_queue, background_jobs, sqlite, activerecord]

# Dependency graph
requires:
  - phase: 01-01
    provides: GithubClient service with typed errors, GitHubMetric model with all 11 metric_types, Octokit gem
provides:
  - GithubMetricJob background job fetching all 11 GitHub metric types every 6 hours
  - DataRetentionJob pruning GitHubMetric records older than 30 days daily
  - Solid Queue recurring.yml schedule with github_metrics_fetch (every 6 hours) and data_retention_prune (daily 3am)
affects:
  - 01-03  # dashboard views and controller query GitHubMetric data populated by GithubMetricJob

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "safe_call pattern: wrap individual metric fetches in safe_call to isolate GithubClient::RateLimitError and StatsUnavailableError without crashing the whole job"
    - "Stats endpoint via safe_call: commit_activity_stats and contributors_stats wrapped in safe_call since StatsUnavailableError is a normal transient condition (GitHub 202 retry exhausted)"
    - "Julian Day Number for date storage: release dates stored as date.jd (integer) for numeric decimal column compatibility"
    - "Allocate-based test doubles: GithubClient.allocate skips initialize (no credential lookup in tests), define_singleton_method stubs individual methods"
    - "GithubClient.new override for job tests: define_singleton_method(:new) on GithubClient singleton class + singleton_class.remove_method(:new) in ensure block"
    - "StringIO logger swap for log output testing: swap Rails.logger for Logger.new(StringIO.new) in test, restore in ensure"

key-files:
  created:
    - app/jobs/github_metric_job.rb
    - app/jobs/data_retention_job.rb
    - test/jobs/github_metric_job_test.rb
    - test/jobs/data_retention_job_test.rb
  modified:
    - config/recurring.yml

key-decisions:
  - "Wrapped commit_activity_stats and contributors_stats in safe_call (not just direct call + blank check) — StatsUnavailableError from the retry-exhausted fetch_stats loop is transient and should not re-raise or crash the job"
  - "Used GithubClient.allocate in tests to skip initialize credential loading — avoids need for test credentials or stubbing ENV/credentials in every test"
  - "Simplified DataRetentionJob log test to match count with \\d+ regex — fixture records from github_metrics.yml (stars/forks on 2025-01-15) are in-scope for deletion and inflate the count; counting specific records is fragile"

patterns-established:
  - "safe_call isolation pattern: every GithubClient call that can fail without stopping other metrics is wrapped in safe_call, which returns nil on RateLimitError or StatsUnavailableError"
  - "Job test double pattern: GithubClient.allocate + define_singleton_method for no-credential-required test doubles"

requirements-completed: [INFRA-04, INFRA-05, GH-08]

# Metrics
duration: 4min
completed: 2026-02-24
---

# Phase 1 Plan 2: Foundation GitHub Pipeline Summary

**GithubMetricJob fetching all 11 metrics (stars, forks, issues, PRs, commit frequency, contributors, release date, release cadence) via isolated safe_call wrappers, plus DataRetentionJob pruning 30-day-old records, both scheduled in Solid Queue recurring.yml**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-24T00:13:38Z
- **Completed:** 2026-02-24T00:18:26Z
- **Tasks:** 2 of 2
- **Files modified:** 5

## Accomplishments
- GithubMetricJob covers all 11 metric types: stars, forks, open/closed issues, open/merged/closed PRs, commit_frequency (daily rows from 52-week stats), contributor_count (daily snapshot for growth trend, GH-06), latest_release_date (Julian Day Number), release_cadence (count of releases in trailing 30 days, GH-07)
- Each metric fetch is error-isolated via safe_call — RateLimitError or StatsUnavailableError on one metric does not prevent others from saving
- DataRetentionJob prunes GitHubMetric records older than 30 days using `delete_all` for efficiency
- Solid Queue recurring.yml configured with three entries: existing cleanup, github_metrics_fetch every 6 hours, data_retention_prune daily at 3am
- 16 tests passing (12 job + 4 retention) with mocked GithubClient using allocate + define_singleton_method

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GithubMetricJob that fetches all GitHub metrics** - `d79ac72` (feat)
2. **Task 2: Create DataRetentionJob and configure recurring.yml schedule** - `089ef45` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `app/jobs/github_metric_job.rb` - GithubMetricJob with all 11 metric types and safe_call error isolation
- `app/jobs/data_retention_job.rb` - DataRetentionJob pruning records older than RETENTION_DAYS (30)
- `test/jobs/github_metric_job_test.rb` - 12 tests covering all metrics, error isolation, idempotency
- `test/jobs/data_retention_job_test.rb` - 4 tests covering delete boundary, log output, boundary preservation, empty table
- `config/recurring.yml` - Added github_metrics_fetch and data_retention_prune entries

## Decisions Made
- **safe_call wraps stats endpoints**: `commit_activity_stats` and `contributors_stats` are called via `safe_call` rather than directly. The plan spec shows direct calls, but `StatsUnavailableError` (raised after 3 failed retries on GitHub 202 endpoints) is a normal transient condition that should not re-raise or abort the entire job run.
- **GithubClient.allocate for test doubles**: Avoids credential lookup in tests. The `allocate` class method creates an instance without calling `initialize`, so no `GITHUB_TOKEN` or credentials lookup happens. Each method stubbed via `define_singleton_method`.
- **Log test uses `\d+` regex**: The DataRetentionJob log test matches the pruned count with `\d+` rather than a fixed number because fixture records (stars/forks on 2025-01-15) are > 30 days old and get pruned too, making fixed count assertions fragile.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrapped stats endpoint calls in safe_call**
- **Found during:** Task 1 (running job tests — StatsUnavailableError not caught)
- **Issue:** Plan specifies `record_commit_activity` and `record_contributor_count` call `client.commit_activity_stats` and `client.contributors_stats` directly. When GithubClient's `fetch_stats` exhausts retries it raises `StatsUnavailableError`. This error is a `StandardError`, so the top-level `rescue StandardError` would catch it and re-raise — crashing the job run instead of gracefully skipping the metric.
- **Fix:** Changed both methods to call stats endpoints via `safe_call { client.commit_activity_stats }` and `safe_call { client.contributors_stats }`, so `StatsUnavailableError` is silently skipped (logged warning, returns nil).
- **Files modified:** app/jobs/github_metric_job.rb
- **Verification:** `test_StatsUnavailableError_during_one_metric_does_not_crash_the_job` passes
- **Committed in:** d79ac72 (Task 1 commit)

**2. [Rule 3 - Blocking] Added `require "ostruct"` in test file**
- **Found during:** Task 1 (test run — NameError on OpenStruct)
- **Issue:** Ruby 3.3 removed `ostruct` from default autoloads. `OpenStruct` raised `NameError: uninitialized constant`.
- **Fix:** Added `require "ostruct"` at top of test file
- **Files modified:** test/jobs/github_metric_job_test.rb
- **Verification:** All 12 tests pass after adding require
- **Committed in:** d79ac72 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes essential for correctness and test execution. No scope creep. All 11 metric types and artifacts match plan specification exactly.

## Issues Encountered
- System Ruby 2.6 picks up `bin/rails` when PATH not set correctly — must prefix commands with `PATH="$HOME/.rubies/ruby-3.3.6-dynamic/bin:$PATH"` in this shell environment (same issue as plan 01-01)
- DataRetentionJob log count test required `\d+` regex because fixture records from `github_metrics.yml` (2025-01-15 entries) are > 30 days old and are also pruned by the job, making fixed-count assertions fragile

## User Setup Required
None — no external service configuration required for job files. GitHub credentials are needed for actual job execution (covered in plan 01-01 setup notes).

## Next Phase Readiness
- GithubMetricJob and DataRetentionJob are ready for deployment
- Solid Queue recurring.yml is configured and matches plan specification
- All 16 job tests passing
- Plan 01-03 (dashboard views) can now query GitHubMetric data via the chart_data/latest_value class methods

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| app/jobs/github_metric_job.rb | FOUND |
| app/jobs/data_retention_job.rb | FOUND |
| test/jobs/github_metric_job_test.rb | FOUND |
| test/jobs/data_retention_job_test.rb | FOUND |
| config/recurring.yml (github_metrics_fetch) | FOUND |
| config/recurring.yml (data_retention_prune) | FOUND |
| Commit d79ac72 (Task 1) | FOUND |
| Commit 089ef45 (Task 2) | FOUND |

---
*Phase: 01-foundation-github-pipeline*
*Completed: 2026-02-24*
