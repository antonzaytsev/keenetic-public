# Keenetic Dashboard App - Development Plan

Local network application that interfaces with a Keenetic router to display and manage connected clients, router resources, and network status.

---

## Phase 1: Project Foundation

### 1.1 Project Structure Setup
- [ ] Create main project directory structure
- [ ] Initialize git repository
- [ ] Create `.gitignore` (ignore `.env`, `node_modules/`, `vendor/`, build outputs)
- [ ] Create `docker-compose.yml` with service definitions

### 1.2 Docker Services Configuration
- [ ] **backend**: Ruby service (Puma, binds to `0.0.0.0`, port via `BACKEND_PORT`, default 4000)
- [ ] **frontend**: React development server (Vite, binds to `0.0.0.0`, port via `FRONTEND_PORT`, default 3000)
- [ ] Define volumes for code hot-reloading
- [ ] Set up internal network for service communication
- [ ] Port mapping: internal and external ports match, controlled by env variables
- [ ] Vite proxy uses Docker service name (`backend`) for inter-container communication
- [ ] `BACKEND_HOST` used by frontend for browser requests (default: `localhost`)

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

## Phase 2: Backend Ruby Service

### 2.1 Ruby Application Bootstrap
- [ ] Create Roda-based API application
- [ ] Set up Bundler with `Gemfile`
- [ ] Configure environment variables handling
- [ ] Set up JSON serialization
- [ ] Configure CORS middleware (`rack-cors`)
- [ ] Add error handling with meaningful JSON responses (500, 404)

### 2.2 Keenetic Communication Library

> **Note:** This library will be extracted into a separate Ruby gem in the future.
> Design it as a standalone, self-contained package from the start.

**Gem-Ready Architecture Requirements:**
- [ ] Use `Keenetic` as top-level namespace
- [ ] Self-contained configuration (no app dependencies)
- [ ] Own version constant (`Keenetic::VERSION`)
- [ ] Minimal external dependencies (Typhoeus for HTTP, digest libs)
- [ ] No Rails/Roda/framework-specific code
- [ ] Configuration via block: `Keenetic.configure { |c| c.host = '...' }`
- [ ] Thread-safe client instances

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
- [ ] HTTP request handling (GET, POST)
- [ ] Authentication flow (challenge-response with MD5+SHA256)
- [ ] Cookie/session management
- [ ] Connection pooling and timeouts
- [ ] Error handling and retry logic
- [ ] Configurable logger (defaults to null logger)

**Layer 2 - API Resources**
- [ ] `Keenetic::Resources::Devices` - connected clients management
- [ ] `Keenetic::Resources::System` - router resources (RAM, CPU, storage)
- [ ] `Keenetic::Resources::Network` - interfaces, ports status
- [ ] `Keenetic::Resources::WiFi` - wireless networks info

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
- [ ] `GET /api/devices` - list connected clients
- [ ] `GET /api/devices/:mac` - single device details
- [ ] `PATCH /api/devices/:mac` - update device (name, access)
- [ ] `GET /api/system/resources` - RAM, CPU, storage
- [ ] `GET /api/system/info` - router model, firmware
- [ ] `GET /api/network/interfaces` - network interfaces status

### 2.4 Backend Testing
- [ ] Set up RSpec
- [ ] Unit tests for Keenetic library (with stubbed HTTP)
- [ ] Integration tests for API endpoints

---

## Phase 3: Frontend React Service

### 3.1 React Application Bootstrap
- [ ] Create React app with Vite
- [ ] Set up TypeScript
- [ ] Configure API proxy to backend
- [ ] Install dependencies (axios/fetch, routing)

### 3.2 Design System (Keenetic-inspired)

**Color Palette:**
```
Background Main:    #0d1117
Background Cards:   #161b22
Primary Accent:     #58a6ff (blue links/active)
Success:            #3fb950 (connected status)
Warning:            #d29922 (disabled badges)
Text Primary:       #c9d1d9
Text Secondary:     #8b949e
Border:             #30363d
```

**Components:**
- [ ] Card/Panel component
- [ ] Status badge (connected/disabled)
- [ ] Toggle switch
- [ ] Data table
- [ ] Navigation sidebar
- [ ] Chart components (for traffic/resources)

### 3.3 Pages & Features

**Dashboard Page:**
- [ ] Router status summary
- [ ] Resource usage (RAM, CPU) with visual indicators
- [ ] Quick stats cards

**Devices Page:**
- [ ] Table of connected clients
- [ ] Columns: Name, IP, MAC, Interface, Status, Actions
- [ ] Inline editing for device name
- [ ] Filtering by segment (Home/Secondary)

**System Page:**
- [ ] Detailed resource consumption
- [ ] Network interfaces status
- [ ] Port status visualization

### 3.4 State Management
- [ ] Set up React Query or SWR for data fetching
- [ ] Auto-refresh for live data
- [ ] Optimistic updates for modifications

---

## Phase 4: Integration

### 4.1 API Integration
- [ ] Connect frontend to backend API
- [ ] Handle loading/error states
- [ ] Implement polling for real-time updates

### 4.2 CORS & Proxy Configuration
- [ ] Configure backend CORS headers
- [ ] Set up Vite proxy for development
- [ ] Nginx configuration for production

---

## Phase 5: Polish & Production

### 5.1 Error Handling
- [ ] Backend: Graceful error responses
- [ ] Frontend: User-friendly error messages
- [ ] Handle router unreachable scenarios

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
│   │   └── environment.rb
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
        ├── api/
        │   ├── client.ts
        │   ├── devices.ts
        │   └── system.ts
        ├── components/
        │   ├── ui/
        │   │   ├── Card.tsx
        │   │   ├── Badge.tsx
        │   │   ├── Toggle.tsx
        │   │   ├── Table.tsx
        │   │   └── Chart.tsx
        │   ├── layout/
        │   │   ├── Sidebar.tsx
        │   │   └── Header.tsx
        │   └── devices/
        │       ├── DeviceList.tsx
        │       └── DeviceRow.tsx
        ├── pages/
        │   ├── Dashboard.tsx
        │   ├── Devices.tsx
        │   └── System.tsx
        ├── hooks/
        │   ├── useDevices.ts
        │   └── useSystem.ts
        └── styles/
            ├── globals.css
            └── variables.css
```

---

## Implementation Order

1. **Phase 1** → Docker setup with placeholder services
2. **Phase 2.1-2.2** → Backend with Keenetic library (core functionality)
3. **Phase 3.1-3.2** → Frontend skeleton with design system
4. **Phase 2.3** → Backend API endpoints
5. **Phase 3.3-3.4** → Frontend pages and features
6. **Phase 4** → Integration and testing
7. **Phase 5** → Production readiness

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

