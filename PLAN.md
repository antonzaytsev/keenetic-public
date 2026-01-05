# Keenetic Dashboard App - Development Plan

Local network application that interfaces with a Keenetic router to display and manage connected clients, router resources, and network status.

---

## Phase 1: Project Foundation ✅

### 1.1 Project Structure Setup
- [x] Create main project directory structure
- [x] Initialize git repository
- [x] Create `.gitignore` (ignore `.env`, `node_modules/`, `vendor/`, build outputs)
- [x] Create `docker-compose.yml` with service definitions

### 1.2 Docker Services Configuration
- [x] **backend**: Ruby service (Puma, binds to `0.0.0.0`, port via `BACKEND_PORT`, default 4000)
- [x] **frontend**: React development server (Vite, binds to `0.0.0.0`, port via `FRONTEND_PORT`, default 3000)
- [x] Define volumes for code hot-reloading
- [x] Set up internal network for service communication
- [x] Port mapping: internal and external ports match, controlled by env variables
- [x] Vite proxy uses Docker service name (`backend`) for inter-container communication
- [x] `BACKEND_HOST` used by frontend for browser requests (default: `localhost`)

**Docker Philosophy:**
- Minimal Dockerfiles - only base image and workdir, no CMD/EXPOSE/dependency installation
- Base images: `ruby:4.0-slim`, `node:25-slim`
- Commands and ports defined in `docker-compose.yml` (single source of truth)
- Dependencies stored in application folders (gitignored):
  - Backend: `vendor/bundle` (via `BUNDLE_PATH` env var)
  - Frontend: `node_modules`, `.pnpm-store`
- Manual dependency installation via `docker compose run` commands:
  ```bash
  docker compose run --rm backend bundle install
  docker compose run --rm frontend pnpm install
  ```

**Ruby 4.0 Notes:**
- `logger` gem must be explicitly added (removed from stdlib)

**Hot Reload:**
- Backend: `rerun` gem watches file changes and restarts Rackup server
- Frontend: Vite's built-in HMR (Hot Module Replacement)

**pnpm Configuration (for Docker compatibility):**
- `node-linker=hoisted` - flat node_modules structure (npm-style)
- `package-import-method=copy` - copy files instead of symlinks
- `symlink=false` - disable symlinks to avoid issues with bind mounts

---

## Phase 2: Backend Ruby Service ✅

### 2.1 Ruby Application Bootstrap
- [x] Create Roda-based API application
- [x] Set up Bundler with `Gemfile`
- [x] Configure environment variables handling
- [x] Set up JSON serialization
- [x] Configure CORS middleware (`rack-cors`)
- [x] Add error handling with meaningful JSON responses (500, 404)

### 2.2 Keenetic Communication Library

> **Note:** This library will be extracted into a separate Ruby gem in the future.
> Design it as a standalone, self-contained package from the start.

**Gem-Ready Architecture Requirements:**
- [x] Use `Keenetic` as top-level namespace
- [x] Self-contained configuration (no app dependencies)
- [x] Own version constant (`Keenetic::VERSION`)
- [x] Minimal external dependencies (Typhoeus for HTTP, digest libs)
- [x] No Rails/Roda/framework-specific code
- [x] Configuration via block: `Keenetic.configure { |c| c.host = '...' }`
- [x] Thread-safe client instances

**Library File Structure (inside `backend/lib/keenetic/`):**
```
keenetic/
├── version.rb           # VERSION constant
├── configuration.rb     # Configuration class
├── client.rb            # Base HTTP client
├── errors.rb            # Custom error classes
├── resources/
│   ├── base.rb          # Base resource class
│   ├── devices.rb       # Devices API
│   ├── system.rb        # System API
│   ├── network.rb       # Network API
│   └── wifi.rb          # WiFi API
└── keenetic.rb          # Main entry point (requires all, exposes configure)
```

**Layer 1 - Base Client (`Keenetic::Client`)**
- [x] HTTP request handling (GET, POST)
- [x] Authentication flow (challenge-response with MD5+SHA256)
- [x] Cookie/session management
- [x] Connection pooling and timeouts
- [x] Error handling and retry logic
- [x] Configurable logger (defaults to null logger)

**Layer 2 - API Resources**
- [x] `Keenetic::Resources::Devices` - connected clients management
- [x] `Keenetic::Resources::System` - router resources (RAM, CPU, storage)
- [x] `Keenetic::Resources::Network` - interfaces, ports status
- [x] `Keenetic::Resources::WiFi` - wireless networks info

**Public API Design:**
```ruby
# Configuration
Keenetic.configure do |config|
  config.host = '192.168.1.1'
  config.login = 'admin'
  config.password = 'secret'
  config.logger = Logger.new(STDOUT)
end

# Usage
client = Keenetic::Client.new
client.devices.all
client.devices.find(mac: 'AA:BB:CC:DD:EE:FF')
client.system.resources
client.network.interfaces
```

### 2.3 API Endpoints
- [x] `GET /api/devices` - list connected clients
- [x] `GET /api/devices/:mac` - single device details
- [x] `PATCH /api/devices/:mac` - update device (name, access)
- [x] `GET /api/system/resources` - RAM, CPU, storage
- [x] `GET /api/system/info` - router model, firmware
- [x] `GET /api/network/interfaces` - network interfaces status

### 2.4 Backend Testing
- [x] Set up RSpec
- [x] Unit tests for Keenetic library (with stubbed HTTP)
- [x] Integration tests for API endpoints

---

## Phase 3: Frontend React Service ✅

### 3.1 React Application Bootstrap
- [x] Create React app with Vite
- [x] Set up TypeScript
- [x] Configure API proxy to backend
- [x] Install dependencies (axios/fetch, routing)

### 3.2 Design System (Keenetic-inspired)

**Color Palette:**
```
Background Main:    #0a0e14
Background Cards:   #12171e
Primary Accent:     #58a6ff (blue links/active)
Success:            #3fb950 (connected status)
Warning:            #d29922 (disabled badges)
Text Primary:       #e6edf3
Text Secondary:     #8b949e
Border:             #21262d
```

**Components:**
- [x] Card/Panel component
- [x] Status badge (connected/disabled)
- [x] Toggle switch
- [x] Data table
- [x] Navigation sidebar
- [x] Progress components (linear + circular for traffic/resources)

### 3.3 Pages & Features

**Dashboard Page:**
- [x] Router status summary
- [x] Resource usage (RAM, CPU) with visual indicators
- [x] Quick stats cards

**Devices Page:**
- [x] Table of connected clients
- [x] Columns: Name, IP, MAC, Interface, Status, Actions
- [x] Inline editing for device name
- [x] Filtering by segment (Home/Secondary)

**System Page:**
- [x] Detailed resource consumption
- [x] Network interfaces status
- [x] Port status visualization

### 3.4 State Management
- [x] Set up React Query for data fetching
- [x] Auto-refresh for live data
- [x] Optimistic updates for modifications

---

## Phase 4: Integration

### 4.1 API Integration
- [x] Connect frontend to backend API
- [x] Handle loading/error states
- [x] Implement polling for real-time updates

### 4.2 CORS & Proxy Configuration
- [x] Configure backend CORS headers
- [x] Set up Vite proxy for development
- [ ] Nginx configuration for production

---

## Phase 5: Polish & Production

### 5.1 Error Handling
- [x] Backend: Graceful error responses
- [x] Frontend: User-friendly error messages
- [x] Handle router unreachable scenarios

### 5.2 Production Docker Setup
- [ ] Multi-stage Dockerfile for frontend (build + nginx)
- [ ] Production Ruby configuration
- [ ] Docker Compose production profile

### 5.3 Documentation
- [ ] README with setup instructions
- [ ] Environment variables documentation
- [ ] API documentation

---

## File Structure

```
keenetic-public/
├── docker-compose.yml
├── .env.example
├── README.md
├── PLAN.md
│
├── backend/
│   ├── Dockerfile
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── config.ru
│   ├── app.rb
│   ├── config/
│   │   └── puma.rb
│   ├── lib/
│   │   ├── keenetic.rb            # Main entry point
│   │   └── keenetic/
│   │       ├── version.rb         # VERSION constant
│   │       ├── configuration.rb   # Configuration class
│   │       ├── client.rb          # Base HTTP client
│   │       ├── errors.rb          # Custom error classes
│   │       └── resources/
│   │           ├── base.rb        # Base resource class
│   │           ├── devices.rb     # Devices API
│   │           ├── system.rb      # System API
│   │           ├── network.rb     # Network API
│   │           └── wifi.rb        # WiFi API
│   └── spec/
│       ├── spec_helper.rb
│       ├── lib/
│       │   └── keenetic/
│       │       ├── client_spec.rb
│       │       ├── configuration_spec.rb
│       │       └── resources/
│       │           ├── devices_spec.rb
│       │           └── system_spec.rb
│       └── integration/
│           └── api_spec.rb
│
└── frontend/
    ├── Dockerfile
    ├── package.json
    ├── pnpm-lock.yaml
    ├── tsconfig.json
    ├── vite.config.ts
    ├── index.html
    └── src/
        ├── main.tsx
        ├── App.tsx
        ├── vite-env.d.ts
        ├── api/
        │   ├── client.ts
        │   ├── types.ts
        │   └── index.ts
        ├── components/
        │   ├── ui/
        │   │   ├── Card.tsx
        │   │   ├── Badge.tsx
        │   │   ├── Toggle.tsx
        │   │   ├── Table.tsx
        │   │   ├── Progress.tsx
        │   │   ├── Input.tsx
        │   │   └── index.ts
        │   └── layout/
        │       ├── Sidebar.tsx
        │       ├── Header.tsx
        │       ├── Layout.tsx
        │       └── index.ts
        ├── pages/
        │   ├── Dashboard.tsx
        │   ├── Devices.tsx
        │   ├── System.tsx
        │   └── index.ts
        ├── hooks/
        │   ├── useDevices.ts
        │   ├── useSystem.ts
        │   ├── useNetwork.ts
        │   └── index.ts
        └── styles/
            └── globals.css
```

---

## Implementation Order

1. **Phase 1** → Docker setup with placeholder services ✅
2. **Phase 2.1-2.2** → Backend with Keenetic library (core functionality) ✅
3. **Phase 3.1-3.2** → Frontend skeleton with design system ✅
4. **Phase 2.3** → Backend API endpoints ✅
5. **Phase 3.3-3.4** → Frontend pages and features ✅
6. **Phase 4** → Integration and testing ✅
7. **Phase 5** → Production readiness (partial)

---

## Environment Variables

```
# Router connection
KEENETIC_HOST=192.168.1.1
KEENETIC_LOGIN=admin
KEENETIC_PASSWORD=your_password

# Backend
RACK_ENV=development
BACKEND_HOST=localhost
BACKEND_PORT=4000

# Frontend
FRONTEND_PORT=3000
```

**Notes:**
- Services always bind to `0.0.0.0` inside containers (configured in Puma/Vite)
- `BACKEND_HOST` is for browser requests from frontend (default: `localhost`)
- `VITE_API_URL` uses Docker service name (`backend`) for proxy (inter-container)
- `VITE_BACKEND_URL` uses `BACKEND_HOST` for direct browser requests
