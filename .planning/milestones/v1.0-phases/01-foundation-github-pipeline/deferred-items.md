# Deferred Items

## Out-of-scope issues discovered during 01-03 execution

### Pre-existing: DataRetentionJobTest logger pollution

**Discovered during:** Task 2 (full test suite run)
**Issue:** `DataRetentionJobTest#test_logs_the_count_of_pruned_records` swaps `Rails.logger` with a `StringIO`-backed test logger. If `DataRetentionJob.perform_now` raises before the `ensure` block restores the logger, subsequent tests receive a `nil` or invalid logger causing `ArgumentError: wrong number of arguments (given 0, expected 1)` in DashboardControllerTest tests.
**Scope:** Pre-existing from plan 01-02 (DataRetentionJob tests). Not caused by plan 01-03 changes.
**Fix needed:** In `test/jobs/data_retention_job_test.rb`, the `ensure` block already exists at line 32-33. The actual failure is `assert_match` on line 31 where `log_output` doesn't match because `DataRetentionJob` may not log in the expected format. Needs investigation in plan 01-02 scope.
**Impact:** When running full test suite (`bin/rails test`), 6 DashboardControllerTest tests fail due to logger pollution. Running controller tests in isolation (`bin/rails test test/controllers/dashboard_controller_test.rb`) shows all 6 pass correctly.
