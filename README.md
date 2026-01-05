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
cp .env.example .env
docker compose build
docker compose run --rm backend bundle install
docker compose run --rm frontend pnpm install
docker compose up
```

## Documentation

See [PLAN.md](PLAN.md) for development roadmap.

