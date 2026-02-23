# Codebase Structure

**Analysis Date:** 2026-02-23

## Directory Layout

```
analytics-dashboard/
├── app/                   # Application code
│   ├── assets/           # Static assets (images, stylesheets)
│   ├── controllers/       # HTTP request handlers
│   ├── helpers/          # View helper methods
│   ├── javascript/       # Client-side JavaScript (Stimulus, Turbo)
│   ├── jobs/             # Background job definitions
│   ├── mailers/          # Email templates and mailers
│   ├── models/           # ActiveRecord models and concerns
│   └── views/            # ERB templates organized by controller
├── bin/                  # Executable scripts
├── config/               # Rails configuration files
├── db/                   # Database schema, migrations, seeds
├── lib/                  # Custom libraries and utilities
├── public/               # Static files, error pages
├── test/                 # Test suite
├── vendor/               # Vendored dependencies
├── .github/              # GitHub workflows and configuration
├── .kamal/               # Kamal deployment configuration
├── .planning/            # GSD planning documents
├── Dockerfile            # Container image definition
├── Gemfile               # Ruby gem dependencies
├── config.ru             # Rack application entrypoint
└── Rakefile              # Rails task definitions
```

## Directory Purposes

**app/:**
- Purpose: All application code organized by Rails convention
- Contains: Controllers, models, views, helpers, assets, JavaScript
- Key files: `app/controllers/`, `app/models/`, `app/views/`

**app/controllers/:**
- Purpose: HTTP request handlers and routing targets
- Contains: ActionController subclasses responding to routes
- Key files: `application_controller.rb` (base class), `dashboard_controller.rb` (dashboard)

**app/controllers/concerns/:**
- Purpose: Shared controller behavior (currently empty)
- Contains: Module mixins included in multiple controllers
- Key files: None yet

**app/models/:**
- Purpose: Domain model objects and database persistence logic
- Contains: ActiveRecord model classes
- Key files: `application_record.rb` (base class), no domain models yet

**app/models/concerns/:**
- Purpose: Shared model behavior and validations
- Contains: Module mixins included in multiple models
- Key files: None yet

**app/views/:**
- Purpose: HTML templates rendered by controllers
- Contains: ERB template files organized by controller name
- Key files: `layouts/application.html.erb` (main layout), `dashboard/index.html.erb` (dashboard view), `pwa/` (PWA manifest/service worker)

**app/views/layouts/:**
- Purpose: Master templates wrapping controller-specific views
- Contains: HTML layout templates
- Key files: `application.html.erb` (primary layout with DOCTYPE, stylesheets, scripts)

**app/views/pwa/:**
- Purpose: Progressive Web App configuration (disabled by default)
- Contains: `manifest.json.erb` and `service-worker.js` templates
- Key files: Currently commented out in routes

**app/javascript/:**
- Purpose: Client-side JavaScript code
- Contains: Stimulus controllers, entry point, imports
- Key files: `application.js` (main entry point), `controllers/` (Stimulus controllers)

**app/javascript/controllers/:**
- Purpose: Stimulus controller definitions
- Contains: ES6 classes extending Stimulus Controller
- Key files: `application.js` (bootstrap), `index.js` (auto-loader), `hello_controller.js` (example)

**app/assets/:**
- Purpose: Static assets compiled by Propshaft
- Contains: Stylesheets and images
- Key files: `stylesheets/application.css` (main stylesheet), `images/` (PNG/SVG assets)

**app/helpers/:**
- Purpose: View helper methods
- Contains: Module classes with utility methods included in views
- Key files: `application_helper.rb` (base helpers), `dashboard_helper.rb` (dashboard-specific)

**app/jobs/:**
- Purpose: Background job definitions using Solid Queue
- Contains: ActiveJob subclasses
- Key files: `application_job.rb` (base class)

**app/mailers/:**
- Purpose: Email generation and delivery
- Contains: ActionMailer subclasses
- Key files: `application_mailer.rb` (base mailer)

**bin/:**
- Purpose: Executable scripts for common tasks
- Contains: Rails command-line tools and custom scripts
- Key files: `rails` (Rails CLI), `setup` (development setup), `docker-entrypoint` (container startup)

**config/:**
- Purpose: Rails application configuration
- Contains: Routes, environment-specific settings, gem configuration
- Key files: `routes.rb` (HTTP routing), `application.rb` (core config), `puma.rb` (server config)

**config/environments/:**
- Purpose: Environment-specific configuration overrides
- Contains: Ruby files for development, test, production settings
- Key files: `development.rb`, `test.rb`, `production.rb`

**db/:**
- Purpose: Database schema and data
- Contains: Migrations (currently none), seeds, Solid Suite schemas
- Key files: `cache_schema.rb` (Solid Cache), `queue_schema.rb` (Solid Queue), `cable_schema.rb` (Solid Cable)

**lib/:**
- Purpose: Custom libraries and utilities
- Contains: Application-specific code not following Rails conventions
- Key files: `tasks/` subdirectory for custom Rake tasks (currently empty)

**public/:**
- Purpose: Static files served directly by web server
- Contains: Error pages, robots.txt, favicon
- Key files: `icon.png`, `icon.svg`, `404.html`, `500.html`, `422.html`, `400.html`

**test/:**
- Purpose: Automated test suite
- Contains: Tests organized by type
- Key files: `test_helper.rb` (test configuration), specific test directories below

**test/controllers/:**
- Purpose: Controller integration tests
- Contains: ActionDispatch::IntegrationTest subclasses
- Key files: `dashboard_controller_test.rb` (dashboard controller tests)

**test/system/:**
- Purpose: End-to-end browser tests
- Contains: ApplicationSystemTestCase subclasses using Selenium
- Key files: Currently empty

**test/models/:**
- Purpose: Model unit tests
- Contains: Model-specific test cases
- Key files: Currently empty

**test/fixtures/:**
- Purpose: Test data fixtures
- Contains: YAML files defining test data
- Key files: `files/` subdirectory for file fixtures

**.kamal/:**
- Purpose: Container orchestration and deployment configuration
- Contains: Kamal deploy configuration and secrets
- Key files: `secrets` (encrypted deployment secrets), `hooks/` (deployment hooks)

**.github/:**
- Purpose: GitHub-specific configuration
- Contains: Workflows, issue templates, etc.
- Key files: `workflows/` subdirectory

**.planning/codebase/:**
- Purpose: GSD codebase analysis documents
- Contains: Markdown documentation of architecture, conventions, etc.
- Key files: `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `TESTING.md`, `STACK.md`, `INTEGRATIONS.md`, `CONCERNS.md`

## Key File Locations

**Entry Points:**
- `config.ru`: Rack application entrypoint
- `bin/rails`: Rails command-line interface
- `bin/docker-entrypoint`: Docker container entrypoint
- `app/javascript/application.js`: Browser-side JavaScript entry point

**Configuration:**
- `config/routes.rb`: HTTP route definitions (currently 1 main route: root to dashboard)
- `config/application.rb`: Core Rails configuration and defaults
- `config/environments/production.rb`: Production-specific settings
- `config/puma.rb`: Puma web server configuration
- `Gemfile`: Ruby gem dependencies

**Core Logic:**
- `app/controllers/application_controller.rb`: Base controller with shared behavior
- `app/controllers/dashboard_controller.rb`: Dashboard HTTP handler
- `app/models/application_record.rb`: Base model class
- `app/views/layouts/application.html.erb`: Primary HTML layout
- `app/views/dashboard/index.html.erb`: Dashboard view with Chartkick integration

**Testing:**
- `test/test_helper.rb`: Test configuration and setup
- `test/application_system_test_case.rb`: System test base class with Selenium
- `test/controllers/dashboard_controller_test.rb`: Dashboard controller tests

## Naming Conventions

**Files:**
- Controllers: `*_controller.rb` (e.g., `dashboard_controller.rb`)
- Models: `singular_name.rb` (e.g., `user.rb`)
- Views: `action_name.html.erb` organized in `views/controller_name/` (e.g., `views/dashboard/index.html.erb`)
- Stimulus controllers: `*_controller.js` (e.g., `hello_controller.js`)
- Tests: `*_test.rb` (e.g., `dashboard_controller_test.rb`)
- Helpers: `*_helper.rb` (e.g., `dashboard_helper.rb`)
- Jobs: `*_job.rb` (e.g., `send_email_job.rb`)

**Directories:**
- Controllers: `app/controllers/` with optional `concerns/` subdirectory
- Models: `app/models/` with optional `concerns/` subdirectory
- Views: `app/views/controller_name/` (plural controller name)
- JavaScript controllers: `app/javascript/controllers/`
- Tests: `test/controllers/`, `test/models/`, `test/system/`, etc.

## Where to Add New Code

**New Feature/Page:**
1. Create controller: `app/controllers/feature_controller.rb`
2. Add route: `config/routes.rb`
3. Create view template: `app/views/feature/action.html.erb`
4. Add tests: `test/controllers/feature_controller_test.rb` and `test/system/feature_test.rb`

**New Model:**
1. Generate model: `bin/rails generate model ModelName field:type`
2. Define validations in: `app/models/model_name.rb`
3. Add tests: `test/models/model_name_test.rb`

**New Stimulus Controller:**
1. Create: `app/javascript/controllers/feature_controller.js`
2. Extend `Controller` from `@hotwired/stimulus`
3. Automatically registered via `app/javascript/controllers/index.js`
4. Use in views: `<div data-controller="feature">`

**Shared Logic:**
- View helpers: `app/helpers/` (included in all views)
- Model concerns: `app/models/concerns/` (included in models)
- Controller concerns: `app/controllers/concerns/` (included in controllers)

## Special Directories

**vendor/:**
- Purpose: Vendored third-party code
- Generated: Yes (typically from `bundle install`)
- Committed: No (ignored by .gitignore)

**tmp/:**
- Purpose: Temporary files (if present)
- Generated: Yes (Rails creates on demand)
- Committed: No (ignored by .gitignore)

**log/:**
- Purpose: Application logs
- Generated: Yes (Rails writes at runtime)
- Committed: No (ignored by .gitignore)

**public/packs/ or app/assets/builds/:**
- Purpose: Compiled assets (Propshaft output)
- Generated: Yes (from `assets:precompile`)
- Committed: No (generated during build)

**db/migrate/:**
- Purpose: Database migration files
- Generated: Yes (from `generate migration`)
- Committed: Yes (part of schema versioning)
- Note: Currently empty (no migrations yet)

---

*Structure analysis: 2026-02-23*
