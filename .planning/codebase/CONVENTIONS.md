# Coding Conventions

**Analysis Date:** 2026-02-23

## Naming Patterns

**Files:**
- Controllers: `{name}_controller.rb` (e.g., `app/controllers/dashboard_controller.rb`)
- Models: `{singular_name}.rb` (e.g., `app/models/application_record.rb`)
- Mailers: `{name}_mailer.rb` (e.g., `app/mailers/application_mailer.rb`)
- Jobs: `{name}_job.rb` (e.g., `app/jobs/application_job.rb`)
- Helpers: `{name}_helper.rb` (e.g., `app/helpers/dashboard_helper.rb`)
- Tests: `{name}_test.rb` (e.g., `test/controllers/dashboard_controller_test.rb`)

**Classes:**
- CamelCase with full words
- Base/abstract classes prefixed with `Application` (e.g., `ApplicationController`, `ApplicationRecord`, `ApplicationMailer`, `ApplicationJob`)
- Domain classes without prefix (e.g., `DashboardController`)

**Methods:**
- snake_case for method names
- Example: `def index`, `def show`, `def create`
- Rails action methods follow REST conventions (index, show, new, create, edit, update, destroy)

**Variables:**
- snake_case for local variables
- Constants in UPPER_SNAKE_CASE
- Instance variables prefixed with `@`

## Code Style

**Formatting:**
- Omakase Ruby styling via `rubocop-rails-omakase` gem
- Configuration: `.rubocop.yml` inherits from `rubocop-rails-omakase` with overrides
- Two-space indentation (Rails standard)

**Linting:**
- RuboCop with Rails-specific rules via `rubocop-rails-omakase`
- Available in development/test group
- Run: `bin/rubocop` script provided

**Static Analysis:**
- Brakeman for security vulnerabilities (development/test group)
- Bundler-audit for gem security issues with config at `config/bundler-audit.yml`

## Rails Conventions

**Controllers:**
- Inherit from `ApplicationController`
- Location: `app/controllers/`
- Example: `class DashboardController < ApplicationController`
- Minimal logic - delegate to models when possible

**Models:**
- Inherit from `ApplicationRecord` (which inherits `ActiveRecord::Base`)
- Location: `app/models/`
- ActiveRecord naming conventions (pluralized table names, singular class names)

**Mailers:**
- Inherit from `ApplicationMailer`
- Location: `app/mailers/`
- Define email delivery actions as methods

**Jobs:**
- Inherit from `ApplicationJob`
- Location: `app/jobs/`
- Use ActiveJob for background jobs

**Helpers:**
- Location: `app/helpers/`
- Application-wide helpers in `application_helper.rb`
- Controller-specific helpers in `{controller}_helper.rb`

## Import Organization

**Rails requires:**
- All standard Rails components loaded automatically via Rails initialization
- No explicit import statements needed for Rails classes (automatic via Zeitwerk autoloading)
- Configuration: `config/application.rb` sets autoload paths

**External Gems:**
- Loaded via Bundler in `Gemfile`
- Development/test-specific gems in separate groups (`:development, :test` and `:test`)

## Error Handling

**Patterns:**
- Rails exception handling in controllers via exception handlers
- ActiveRecord validation errors handled at model level
- System tests use Capybara assertions for error verification
- Integration tests use standard HTTP assertions (e.g., `assert_response :success`)

## Logging

**Framework:** Rails Logger (built-in)

**Patterns:**
- Use `Rails.logger` for logging
- Configured per-environment in `config/environments/`
- Tests don't log unless explicitly configured

## Comments

**When to Comment:**
- Minimal comments expected - Rails conventions are self-documenting
- Only for non-obvious business logic
- Action methods in controllers are typically self-explanatory via naming

**Documentation:**
- Rails guides are source of truth for conventions
- Code structure follows Rails 8 defaults

## Function Design

**Size:** Single-responsibility methods preferred

**Parameters:** Minimal parameters (Rails action methods have implicit `params` and implicit rendering)

**Return Values:** Controllers typically return implicit renders; models return query results or values

## Module Design

**Exports:**
- Controller actions are public by default
- Models define public instance/class methods
- Helpers are module methods available in templates

**Concerns:**
- Location: `app/models/concerns/`, `app/controllers/concerns/`
- Use for shared behavior across models or controllers
- Example pattern: `include MySharedConcern`

## Rails Application Structure

**Configuration:**
- `config/application.rb`: Main application class inheriting from `Rails::Application`
- `config/environments/*.rb`: Environment-specific settings (development, test, production)
- `config/routes.rb`: Route definitions using Rails DSL
- `config/database.yml`: Database configuration

**Routing:**
- REST conventions: `get`, `post`, `patch`, `delete`, `put` methods
- Resource routing supported
- Root path defined: `root "dashboard#index"`

---

*Convention analysis: 2026-02-23*
