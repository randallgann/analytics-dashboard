# Technology Stack

**Analysis Date:** 2026-02-23

## Languages

**Primary:**
- Ruby 3.3.6 - Backend application logic, models, controllers, and configuration

**Secondary:**
- JavaScript (ES6+) - Frontend interactivity via import maps
- ERB (Embedded Ruby) - View templates
- HTML/CSS - UI markup and styling

## Runtime

**Environment:**
- Ruby on Rails 8.1.0+ - Web framework with integrated ORM, routing, and templating

**Package Manager:**
- Bundler - Ruby gem dependency management
- Lockfile: `Gemfile.lock` (present)
- npm/yarn - JavaScript package management (minimal usage for chart libraries)
- Lockfile: `package.json` (present)

## Frameworks

**Core:**
- Rails 8.1.0 - Full-stack web framework
- Propshaft - Modern asset pipeline for managing CSS, JavaScript, and images
- Importmap Rails - Lightweight JavaScript dependency management without bundlers

**Frontend:**
- Turbo Rails - SPA-like page acceleration without writing JavaScript
- Stimulus Rails - Modest JavaScript framework for interactions
- Chart.js 4.5.1 - Client-side charting library
- Chartkick 5.0.1 - Rails integration for Chart.js

**Testing:**
- Capybara 3.40.0 - Browser automation and acceptance testing framework
- Selenium WebDriver - WebDriver implementation for Capybara
- Rails system tests - Built-in Rails system testing infrastructure (in `test/system`)

**Build/Dev:**
- Thruster - HTTP asset caching and compression for Puma
- Bootsnap 1.21.1 - Boot time reduction through caching
- Kamal - Docker-based deployment orchestration

## Key Dependencies

**Critical:**
- sqlite3 2.1+ - Lightweight relational database (default storage backend)
- puma 5.0+ - Concurrent Ruby web server
- jbuilder - JSON template engine for API responses
- ActionCable (via Rails) - WebSocket framework for real-time features

**Infrastructure:**
- solid_cache - Durable in-process cache backed by SQLite database
- solid_queue - Job queue system using database instead of external services
- solid_cable - WebSocket adapter using database for broadcasting
- image_processing 1.2+ - Image transformation for Active Storage
- tzinfo-data - Timezone information (Windows/JRuby)

**Development & Security:**
- debug - Ruby debugger with REPL
- brakeman 8.0.1 - Static security analysis for Rails
- bundler-audit 0.9.3 - Audits gems for known vulnerabilities
- rubocop-rails-omakase - Rails-specific linting and code style enforcement
- web-console - Interactive debugging console for development

## Configuration

**Environment:**
- Config via Rails credentials (`config/credentials.yml.enc`)
- Environment variables support via `ENV.fetch()`
- Rails.env-based configuration (development, test, production)

**Build:**
- `Dockerfile` - Multi-stage Docker build for production
- `config/deploy.yml` - Kamal deployment configuration
- Asset pipeline configured in `config/initializers/assets.rb`

**Database:**
- Development: SQLite3 at `storage/development.sqlite3`
- Test: SQLite3 at `storage/test.sqlite3`
- Production: Multi-database setup using SQLite3:
  - Primary: `storage/production.sqlite3` (application data)
  - Cache: `storage/production_cache.sqlite3` (solid_cache backing)
  - Queue: `storage/production_queue.sqlite3` (solid_queue backing)
  - Cable: `storage/production_cable.sqlite3` (solid_cable backing)

**Logging:**
- Development: Console output with deprecation warnings
- Production: STDOUT with request_id tags (configurable via `RAILS_LOG_LEVEL` env var)

## Platform Requirements

**Development:**
- Ruby 3.3.6 (specified in `.ruby-version`)
- Bundler for gem management
- Node.js (for npm/JavaScript dependencies, though minimal)
- SQLite3 development headers

**Production:**
- Docker container runtime
- Kamal deployment orchestration
- Persistent storage volume for SQLite databases (`analytics_dashboard_storage`)
- Network access for container registry (localhost:5555 by default, configurable)
- SSL/TLS termination support (force_ssl enabled, assume_ssl in production config)

**Deployment Target:**
- Docker-based deployment via Kamal
- Configured servers at 192.168.0.1 (default, changeable)
- Container registry support (Docker Hub, DigitalOcean, GitHub Container Registry, etc.)
- Volumes mounted at `/rails/storage` for persistent data

## Database & Storage

**Primary Database:**
- SQLite3 with Active Record ORM
- Multi-database support in production (primary, cache, queue, cable)
- Connection pooling: 5 connections default (configurable via `RAILS_MAX_THREADS`)

**File Storage:**
- Local filesystem (default) at `storage/` or `tmp/storage` in test
- Active Storage support with commented-out S3 and Google Cloud Storage configurations available
- Image processing via libvips

## Caching & Queuing

**Caching:**
- Development: In-memory cache store (`:memory_store`)
- Production: `solid_cache` using dedicated SQLite database

**Background Jobs/Queue:**
- `solid_queue` for job processing
- Configurable workers and dispatchers in `config/queue.yml`
- Default: 3 worker threads, 1 process
- Supports async job dispatch with configurable batch sizes

**WebSockets/Real-time:**
- Async adapter for development
- Test adapter for test environment
- `solid_cable` adapter for production using SQLite
- Polling interval: 0.1 seconds, 1-day message retention

## Assets & Frontend

**Asset Pipeline:**
- Propshaft for asset bundling and versioning
- Importmap Rails for JavaScript module management
- CSS and JavaScript processed via Propshaft
- Fingerprinted assets cached aggressively in production (1-year cache headers)

**Charts & Visualization:**
- Chartkick gem (Rails wrapper)
- Chart.js client-side rendering library

---

*Stack analysis: 2026-02-23*
