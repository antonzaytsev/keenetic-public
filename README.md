# Keenetic Dashboard

Local network web application for monitoring and managing Keenetic routers.

## Features

- View connected clients and their status
- Monitor router resources (RAM, CPU, storage)
- Manage device settings

## Tech Stack

- **Frontend:** React + TypeScript + Vite
- **Backend:** Ruby + Roda
- **Infrastructure:** Docker Compose

## Quick Start

```bash
# Configure environment
cp .env.example .env
# Edit .env with your router credentials

# Install dependencies
docker compose run --rm backend bundle install
docker compose run --rm frontend pnpm install

# Start services
docker compose up
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:4000

## Environment Variables

```
KEENETIC_HOST=192.168.0.1
KEENETIC_LOGIN=admin
KEENETIC_PASSWORD=your_password
BACKEND_PORT=4000
FRONTEND_PORT=3000
```

## Documentation

See [PLAN.md](PLAN.md) for development roadmap.
