# Keenetic Dashboard

Local network web application for monitoring and managing Keenetic routers.

## Features

- **Dashboard** — Router status summary, CPU and RAM usage with visual indicators
- **Devices** — View and manage connected clients, inline name editing, filtering by network segment
- **System** — Detailed resource monitoring, network interfaces status, port visualization

## Tech Stack

- **Frontend:** React 18 + TypeScript + Vite + React Query
- **Backend:** Ruby 4.0 + Roda + Puma
- **Infrastructure:** Docker Compose

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd keenetic-public

# 2. Create environment file
cp .env.example .env
# Edit .env with your router credentials

# 3. Install dependencies
docker compose run --rm backend bundle install
docker compose run --rm frontend pnpm install

# 4. Start services
docker compose up
```

**Access:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:4000

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KEENETIC_HOST` | Router IP address | `192.168.1.1` |
| `KEENETIC_LOGIN` | Router admin username | `admin` |
| `KEENETIC_PASSWORD` | Router admin password | — |
| `BACKEND_PORT` | Backend API port | `4000` |
| `FRONTEND_PORT` | Frontend dev server port | `3000` |
| `BACKEND_HOST` | Backend host for browser requests | `localhost` |
| `RACK_ENV` | Ruby environment | `development` |

## API Reference

All endpoints return JSON with a `timestamp` field.

### Health

```
GET /api/health
```

Response:
```json
{ "status": "healthy", "timestamp": "2025-01-05T12:00:00Z" }
```

### Devices

```
GET /api/devices
```

Returns list of all connected devices.

```json
{
  "devices": [
    {
      "mac": "AA:BB:CC:DD:EE:FF",
      "name": "iPhone",
      "ip": "192.168.1.10",
      "interface": "Bridge0",
      "active": true,
      "registered": true
    }
  ],
  "count": 1,
  "timestamp": "2025-01-05T12:00:00Z"
}
```

```
GET /api/devices/:mac
```

Returns single device details.

```
PATCH /api/devices/:mac
```

Update device properties. Allowed fields: `name`, `access`, `schedule`.

Request body:
```json
{ "name": "New Device Name" }
```

### System

```
GET /api/system/resources
```

Returns router resource usage (RAM, CPU, storage).

```json
{
  "resources": {
    "memory": { "total": 268435456, "used": 134217728, "percent": 50 },
    "cpu": { "load": 15 },
    "uptime": 86400
  },
  "timestamp": "2025-01-05T12:00:00Z"
}
```

```
GET /api/system/info
```

Returns router model and firmware information.

### Network

```
GET /api/network/interfaces
```

Returns network interfaces status.

```json
{
  "interfaces": [
    {
      "id": "Bridge0",
      "type": "bridge",
      "description": "Home network",
      "state": "up",
      "ip": "192.168.1.1"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-05T12:00:00Z"
}
```

### WiFi

```
GET /api/wifi/access-points
```

Returns WiFi access points configuration.

```
GET /api/wifi/clients
```

Returns connected WiFi clients.

## Error Responses

All errors return JSON with `error`, `message`, and `timestamp` fields:

```json
{
  "error": "Authentication Error",
  "message": "Invalid credentials",
  "timestamp": "2025-01-05T12:00:00Z"
}
```

| Status | Error Type |
|--------|------------|
| 400 | Bad Request |
| 401 | Authentication Error |
| 404 | Not Found |
| 503 | Connection Error / Timeout |
| 500 | Internal Server Error |

## Development

### Running Tests

```bash
# Backend tests
docker compose run --rm backend bundle exec rspec

# Frontend tests
docker compose run --rm frontend pnpm test
```

### Project Structure

```
keenetic-public/
├── docker-compose.yml
├── backend/
│   ├── app.rb              # Roda application
│   ├── config/puma.rb      # Puma configuration
│   ├── lib/keenetic/       # Keenetic API client library
│   └── spec/               # RSpec tests
└── frontend/
    ├── src/
    │   ├── api/            # API client
    │   ├── components/     # UI components
    │   ├── hooks/          # React Query hooks
    │   └── pages/          # Page components
    └── vite.config.ts
```

## Documentation

See [PLAN.md](PLAN.md) for development roadmap and architecture details.
