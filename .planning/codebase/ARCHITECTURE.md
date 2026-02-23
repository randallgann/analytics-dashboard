# Architecture

**Analysis Date:** 2026-02-23

## Pattern Overview

**Overall:** Traditional Rails MVC with modern Hotwire integration

**Key Characteristics:**
- Rails 8.1 monolithic application serving server-rendered HTML with client-side enhancements
- Hotwire stack (Turbo + Stimulus) for dynamic interactions without heavy JavaScript framework
- Asset pipeline via Propshaft with ESM import maps for JavaScript
- Containerized deployment via Docker with Kamal orchestration
- Solid Suite (cache, queue, cable) for production data persistence

## Layers

**Presentation Layer (Views):**
- Purpose: Render HTML templates and manage client-side interactions via Stimulus
- Location: `app/views/`, `app/assets/stylesheets/`, `app/javascript/`
- Contains: ERB templates, CSS stylesheets, Stimulus controllers
- Depends on: Helpers, view-level data from controllers
- Used by: Browsers/HTTP clients

**Controller Layer:**
- Purpose: Handle HTTP requests, route to models/services, pass data to views
- Location: `app/controllers/`
- Contains: ActionController subclasses handling request/response cycle
- Depends on: Models, application concerns
- Used by: Rails router

**Model Layer:**
- Purpose: Represent domain objects and persist to database
- Location: `app/models/`
- Contains: ActiveRecord models, model concerns
- Depends on: SQLite3 database schema
- Used by: Controllers, ActiveJob background jobs

**Support Layers:**
- **Helpers:** `app/helpers/` - View helper methods and utilities
- **Jobs:** `app/jobs/` - Background job definitions using Solid Queue
- **Mailers:** `app/mailers/` - Email generation and delivery
- **Assets:** `app/assets/` - Images, stylesheets, compiled assets

## Data Flow

**HTTP Request → Response:**

1. Rails router (`config/routes.rb`) receives request
2. Matches route to controller action (e.g., `DashboardController#index`)
3. Controller processes request, queries models as needed
4. Controller renders view template with instance variables
5. View template outputs ERB/HTML, optionally triggers Stimulus controllers
6. Stimulus controllers enhance DOM with client-side interactivity
7. Response returned to browser with assets (CSS, JS) cached via Propshaft

**Charting Data Flow (Dashboard Example):**

1. `DashboardController#index` action renders without fetching data
2. View template `app/views/dashboard/index.html.erb` renders static chart
3. Chartkick gem converts server-side Ruby data to Chart.js visualization
4. Browser displays interactive chart with Chart.js library

**State Management:**
- Server state: ActiveRecord models in SQLite3 database
- Session state: Rails session store (file-based in development, Solid Cache in production)
- Client state: Browser DOM managed by Stimulus controllers and Turbo

## Key Abstractions

**ApplicationController:**
- Purpose: Base class for all controllers with shared behavior
- Examples: `app/controllers/application_controller.rb`
- Pattern: Enforce browser compatibility via `allow_browser`, manage import map etags

**ApplicationRecord:**
- Purpose: Base class for all ActiveRecord models
- Examples: `app/models/application_record.rb`
- Pattern: Abstract base with primary_abstract_class declaration, inherits from ActiveRecord::Base

**ApplicationHelper:**
- Purpose: Helper methods available in all views
- Examples: `app/helpers/application_helper.rb`
- Pattern: Shared view logic and formatting utilities

**Stimulus Application:**
- Purpose: Bootstrap and manage Stimulus controllers
- Examples: `app/javascript/controllers/application.js`
- Pattern: Initialize Stimulus application, eager-load all controllers via `controllers/**/*_controller.js` convention

## Entry Points

**HTTP Server:**
- Location: `config.ru`
- Triggers: HTTP request to application
- Responsibilities: Load Rails environment and route request to application middleware stack

**Rails CLI:**
- Location: `bin/rails`
- Triggers: Developer invokes `rails` command
- Responsibilities: Execute Rails tasks (server, console, migrations, etc.)

**Docker Container:**
- Location: `Dockerfile` with entrypoint `bin/docker-entrypoint`
- Triggers: Container startup in production
- Responsibilities: Prepare database, start Thruster HTTP server

**Stimulus Bootstrap:**
- Location: `app/javascript/controllers/application.js` invoked from `app/javascript/application.js`
- Triggers: Page load in browser
- Responsibilities: Initialize Stimulus application, register all controllers

## Error Handling

**Strategy:** Rails convention-based error handling

**Patterns:**
- `ApplicationController#allow_browser` enforces modern browser support, returns 406 for unsupported browsers
- 404/422/500 error pages in `public/` directory serve static HTML fallbacks
- Rails development mode shows detailed error pages with stack traces
- Production logs errors via standard Rails logger
- System tests use Selenium WebDriver for browser interaction testing

## Cross-Cutting Concerns

**Logging:** Rails standard logger outputs to STDOUT/STDERR via Rails logger configuration in `config/environments/`

**Validation:** ActiveRecord model validations via `validates` DSL, controller parameter sanitization via Strong Parameters

**Authentication:** Not yet implemented (application defaults to public access)

**CSRF Protection:** Rails CSRF token via `csrf_meta_tags` in layouts, automatic token validation for non-GET requests

---

*Architecture analysis: 2026-02-23*
