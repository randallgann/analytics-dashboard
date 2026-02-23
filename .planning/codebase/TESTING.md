# Testing Patterns

**Analysis Date:** 2026-02-23

## Test Framework

**Runner:**
- Rails built-in test framework (Minitest)
- No separate test runner gem required
- Config: Rails test environment defaults in `config/environment.rb` with `ENV["RAILS_ENV"] ||= "test"`

**Assertion Library:**
- Rails Test::Unit assertions (inherent to Rails test framework)
- Example assertions: `assert_response`, `assert_equal`, `get`, `post`

**System Testing:**
- Capybara for browser automation
- Selenium WebDriver with headless Chrome driver
- Configuration: `test/application_system_test_case.rb`

**Run Commands:**
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests only
bin/rails test:models       # Run model tests only
bin/rails test:controllers  # Run controller tests only
```

## Test File Organization

**Location:**
- Tests co-located in parallel structure to `app/` directory
- `test/controllers/` for controller tests
- `test/models/` for model tests
- `test/integration/` for integration tests
- `test/system/` for system/feature tests
- `test/mailers/` for mailer tests
- `test/helpers/` for helper tests

**Naming:**
- `{name}_test.rb` pattern (e.g., `dashboard_controller_test.rb`)
- Class names: `{Name}Test` or `{Name}ControllerTest` or `{Name}SystemTestCase`

**Structure:**
```
test/
├── test_helper.rb                           # Base test configuration
├── application_system_test_case.rb         # System test base configuration
├── controllers/
│   └── dashboard_controller_test.rb
├── models/
├── integration/
├── system/
├── fixtures/                                # Test data fixtures
│   ├── files/
│   └── [fixtures].yml
└── [other test directories]
```

## Test Structure

**Suite Organization:**
```ruby
require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get dashboard_index_url
    assert_response :success
  end
end
```

**Patterns:**
- Inherit from appropriate test base class: `ActionDispatch::IntegrationTest`, `ActionDispatch::SystemTestCase`, or `ActiveSupport::TestCase`
- Use `test "description"` blocks (Rails convention, equivalent to `def test_description`)
- One assertion per test preferred, or related assertions grouped logically

**Test Helper Setup:**
```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)  # Run tests in parallel
    fixtures :all                                 # Load all fixtures
  end
end
```

**System Tests Base:**
```ruby
# test/application_system_test_case.rb
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
```

## Test Types

**Integration Tests:**
- Location: `test/controllers/`
- Class: `ActionDispatch::IntegrationTest`
- Scope: Test controller actions with HTTP-like methods (`get`, `post`, `patch`, etc.)
- Approach: Send requests to routes and verify responses
- Example: `get dashboard_index_url` followed by `assert_response :success`

**System Tests (Browser):**
- Location: `test/system/`
- Class: `ActionDispatch::SystemTestCase`
- Scope: Full application behavior including JavaScript and browser interactions
- Driver: Selenium WebDriver with headless Chrome
- Approach: Navigate application like a user, verify page content and behavior

**Unit Tests:**
- Location: `test/models/`
- Class: `ActiveSupport::TestCase`
- Scope: Model validation, associations, methods
- Approach: Test individual model logic without HTTP layer

**Fixtures:**
- Location: `test/fixtures/`
- Format: YAML files (e.g., `{model_name}.yml`)
- Loaded automatically via `fixtures :all` in test_helper
- Naming: Pluralized model name (e.g., `dashboards.yml` for Dashboard model)
- Available as variables: `@dashboard = dashboards(:one)`

## Mocking

**Framework:** None detected - Tests use real Rails models and database via fixtures

**Patterns:**
- Fixtures provide test data - real database records used in tests
- Parallel test execution configured to avoid conflicts
- Database is reset between test runs

**What to Mock:**
- External HTTP APIs (if needed, use standard Ruby stubs)
- Third-party services

**What NOT to Mock:**
- ActiveRecord models - use fixtures instead
- Rails framework components

## Coverage

**Requirements:** Not enforced

**View Coverage:** No coverage reporting gem detected

## Common Patterns

**Async Testing:**
- Use Rails test helpers for ActiveJob: `assert_enqueued_with`
- System tests wait for AJAX via Capybara's implicit waits

**Error Testing:**
```ruby
test "should handle invalid input" do
  # Test behavior with invalid data
  post dashboard_url, params: { invalid: "data" }
  # Verify response or behavior
end
```

**Response Assertions:**
- `assert_response :success` - HTTP 200
- `assert_response :redirect` - 3xx redirect
- `assert_response :not_found` - HTTP 404
- `assert_response :error` - 5xx error
- URL assertions: `assert_redirected_to path`

**Fixture Usage:**
```ruby
# Fixtures loaded as instance variables
# test/fixtures/dashboards.yml defines "one" and other fixtures
dashboard = dashboards(:one)  # Access loaded fixture
```

## Test Helper and Configuration

**Setup:**
- `test/test_helper.rb`: Core test configuration
  - Loads Rails test environment
  - Configures parallel test execution
  - Loads all fixtures

- `test/application_system_test_case.rb`: System test driver configuration
  - Uses Selenium WebDriver
  - Headless Chrome browser
  - 1400x1400 screen size

**Teardown:**
- Automatic database cleanup between tests (Rails handles)
- Fixtures are transaction-rolled back (default behavior)

---

*Testing analysis: 2026-02-23*
