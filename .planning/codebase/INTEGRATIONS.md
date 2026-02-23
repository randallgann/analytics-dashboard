# External Integrations

**Analysis Date:** 2026-02-23

## APIs & External Services

**Not detected** - Current implementation contains no external API integrations. The application is self-contained with no HTTP calls to third-party services detected in the codebase.

## Data Storage

**Databases:**
- SQLite3 (primary storage)
  - Connection: Local filesystem-based database files
  - Client: Rails Active Record ORM
  - Adapter: `sqlite3` gem (version 2.1+)
  - Files:
    - Development: `storage/development.sqlite3`
    - Test: `storage/test.sqlite3`
    - Production (multi-database):
      - Application: `storage/production.sqlite3`
      - Cache backing: `storage/production_cache.sqlite3`
      - Queue backing: `storage/production_queue.sqlite3`
      - WebSocket backing: `storage/production_cable.sqlite3`

**File Storage:**
- Local filesystem storage (default)
  - Development: `storage/` directory
  - Test: `tmp/storage` directory
  - Configuration: `config/storage.yml`
  - Adapter: Active Storage with `:local` service
  - Image processing: libvips via `image_processing` gem
  - Commented configurations available for:
    - AWS S3 (requires AWS credentials in Rails credentials)
    - Google Cloud Storage (requires GCS keyfile)
    - Storage mirroring setup

**Caching:**
- solid_cache (in-process cache backed by SQLite)
  - Database: Dedicated `production_cache.sqlite3` in production
  - Configuration: `config/cache.yml`
  - Max size: 256 MB default
  - Namespace: Environment-based (`Rails.env`)
  - Development/test: In-memory cache (`:memory_store`)

## Authentication & Identity

**Auth Provider:**
- Custom authentication (not implemented or not detected)
- Browser security enforced via:
  - Modern browser requirements only (ES6 modules, WebP, CSS nesting, CSS :has)
  - CORS/CSP available but commented out in `config/initializers/content_security_policy.rb`
  - HTTP Basic Auth: Not configured
  - Session management: Rails default session cookies via rack-session

**Access Control:**
- Application-level controller filters
- Rails CSRF protection enabled by default
- Secure cookies in production (force_ssl enabled)

## Monitoring & Observability

**Error Tracking:**
- Not detected - No external error tracking service (Sentry, Rollbar, etc.)
- Built-in Rails error handling and exception logging

**Logs:**
- Development: Console output with SQL query logging and deprecation notices
- Production: STDOUT with request_id tags
- Log level configurable via `RAILS_LOG_LEVEL` environment variable (default: info)
- Health check path silenced: `/up`
- Verbose logging available for:
  - Query execution (development)
  - Background job enqueueing
  - Redirects
  - Asset requests (silenced in development)

**Metrics & Analytics:**
- Not detected - No APM or metrics collection service integrated
- Application exposes `/up` health check endpoint (built-in Rails)

## Email & Communication

**Email Service:**
- Not configured (action_mailer commented-out in production configuration)
- Available configuration at `config/environments/production.rb`:
  - SMTP configuration available but disabled by default
  - Credentials pattern: `Rails.application.credentials.dig(:smtp, :user_name/password)`
  - Default domain: `example.com` (requires customization)
- Test environment: Mail intercepted (not sent)

## CI/CD & Deployment

**Hosting:**
- Docker container-based deployment
- Deployment tool: Kamal (container orchestration)
- Container registry: Localhost:5555 by default (configurable to Docker Hub, GitHub Container Registry, DigitalOcean, etc.)
- Target servers: 192.168.0.1 (web server, configurable)
- Architecture: Linux amd64 (multi-stage Docker build)

**Deployment Configuration:**
- File: `config/deploy.yml`
- Service name: `analytics_dashboard`
- Image name: `analytics_dashboard` (customizable via registry)
- Persistent volume: `analytics_dashboard_storage` mounted at `/rails/storage`
- Environment injection: Via `.kamal/secrets` directory
- Asset path bridging between versions: `/rails/public/assets`

**Build Process:**
- Multi-stage Dockerfile with:
  - Base Ruby 3.3.6 image
  - Build stage for gem compilation
  - Asset precompilation stage
  - Runtime stage with non-root user
- Bootsnap precompilation for faster boot times
- Jemalloc memory allocator enabled for production

**Container Runtime:**
- Puma web server on port 80
- Thruster for HTTP asset caching and compression
- Solid Queue supervisor can run in-process or dedicated machine
- Environment variables:
  - Required: `RAILS_MASTER_KEY` (secret)
  - Optional: `SOLID_QUEUE_IN_PUMA` (default: true), `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `RAILS_LOG_LEVEL`

## Environment Configuration

**Required environment variables:**
- `RAILS_MASTER_KEY` - Master encryption key for credentials (secret)
- `RAILS_LOG_LEVEL` - Log verbosity (optional, default: info)

**Optional environment variables:**
- `RAILS_MAX_THREADS` - Database connection pool size (default: 5)
- `JOB_CONCURRENCY` - Solid Queue process count (default: 1)
- `WEB_CONCURRENCY` - Puma process count (default: 1)
- `SOLID_QUEUE_IN_PUMA` - Run queue in web process (default: true)

**Secrets location:**
- Credentials: `config/credentials.yml.enc` (encrypted with RAILS_MASTER_KEY)
- Master key: `config/master.key` (local development only)
- Deployment secrets: `.kamal/secrets` directory (Kamal convention)
- Password/token recommendations:
  - SMTP credentials can be stored in credentials
  - AWS/GCS credentials can be stored in credentials
  - Container registry credentials via Kamal config

## Database Migration & Management

**Migrations:**
- Rails standard migration system
- Directory: `db/migrate/`
- Supporting directories for multi-database:
  - `db/cache_migrate/` - Cache database migrations
  - `db/queue_migrate/` - Queue database migrations
  - `db/cable_migrate/` - WebSocket adapter database migrations
- Kamal console access: `bin/kamal console` or `bin/kamal dbc` for database console

## Webhooks & Callbacks

**Incoming:**
- Not detected - No webhook endpoints configured

**Outgoing:**
- Not detected - No outgoing webhook calls in codebase

## Infrastructure Dependencies

**Development/Local:**
- SQLite3 CLI tools (installed in Docker)
- libvips for image processing
- Libjemalloc2 for memory management

**Network:**
- Container registry access (for pulling/pushing images)
- Optional: SSH access for remote Docker build via `remote: ssh://docker@docker-builder-server`

**Optional Accessories (commented out in deploy.yml):**
- MySQL 8.0 database server (requires separate configuration)
- Valkey/Redis cache server (requires separate configuration)
- These would be added as Kamal accessories for production use

---

*Integration audit: 2026-02-23*
