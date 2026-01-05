# Keenetic Dashboard App - Development Plan

Local network application that interfaces with a Keenetic router to display and manage connected clients, router resources, and network status.

---

## Phase 1: Project Foundation

### 1.1 Project Structure Setup
- [ ] Create main project directory structure
- [ ] Initialize git repository
- [ ] Create `docker-compose.yml` with service definitions

### 1.2 Docker Services Configuration
- [ ] **backend**: Ruby service (internal port 4000, external configurable via `BACKEND_EXTERNAL_PORT`)
- [ ] **frontend**: React development server (internal port 3000, external configurable via `FRONTEND_EXTERNAL_PORT`)
- [ ] Define volumes for code hot-reloading
- [ ] Set up internal network for service communication
- [ ] Configure port mapping using environment variables with defaults

---

## Phase 2: Backend Ruby Service

### 2.1 Ruby Application Bootstrap
- [ ] Create Roda-based API application
- [ ] Set up Bundler with `Gemfile`
- [ ] Configure environment variables handling
- [ ] Set up JSON serialization

### 2.2 Keenetic Communication Library

> **Note:** This library will be extracted into a separate Ruby gem in the future.
> Design it as a standalone, self-contained package from the start.

**Gem-Ready Architecture Requirements:**
- [ ] Use `Keenetic` as top-level namespace
- [ ] Self-contained configuration (no app dependencies)
- [ ] Own version constant (`Keenetic::VERSION`)
- [ ] Minimal external dependencies (only HTTP client + digest libs)
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
BACKEND_PORT=4000                    # Internal port (inside container)
BACKEND_EXTERNAL_PORT=4000           # External port (host machine)
RACK_ENV=development

# Frontend
FRONTEND_PORT=3000                   # Internal port (inside container)
FRONTEND_EXTERNAL_PORT=3000          # External port (host machine)
VITE_API_URL=http://localhost:4000   # Should match BACKEND_EXTERNAL_PORT
```

**Note:** When changing external ports, update `VITE_API_URL` to match `BACKEND_EXTERNAL_PORT`.

