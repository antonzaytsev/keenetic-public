# Traffic History Collection Plan

## Overview

Poll the Keenetic router every hour to collect device traffic statistics and store them in a local database for historical analysis.

## Problem

The Keenetic API only provides **current/cumulative traffic counters** (`rxbytes`, `txbytes`) per device. These counters:
- Reset when a device disconnects
- Reset when the router reboots
- Provide only cumulative totals, not time-series data

**Solution**: Poll the router periodically, store the data externally, and calculate deltas to build historical graphs.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose                               │
├──────────────────┬──────────────────┬───────────────────────────┤
│                  │                  │                           │
│   Frontend       │    Backend       │    Traffic Collector      │
│   (React)        │    (Roda API)    │    (Background Worker)    │
│                  │                  │                           │
│                  │    ┌─────────────┴────────────┐              │
│                  │    │      SQLite Database     │              │
│                  │    │    (traffic_history.db)  │              │
│                  │    └──────────────────────────┘              │
│                  │                  │                           │
└──────────────────┴──────────────────┴───────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Keenetic Router │
                    │   (polling)      │
                    └──────────────────┘
```

---

## Components

### 1. Database Schema (SQLite)

```sql
-- Traffic readings table (one row per device per poll)
CREATE TABLE traffic_readings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mac VARCHAR(17) NOT NULL,           -- Device MAC address
  recorded_at DATETIME NOT NULL,       -- Timestamp of reading
  rxbytes BIGINT NOT NULL,            -- Cumulative bytes received
  txbytes BIGINT NOT NULL,            -- Cumulative bytes transmitted
  rx_delta BIGINT DEFAULT 0,          -- Bytes received since last reading
  tx_delta BIGINT DEFAULT 0,          -- Bytes transmitted since last reading
  active BOOLEAN DEFAULT true,        -- Device was connected at poll time
  
  UNIQUE(mac, recorded_at)
);

CREATE INDEX idx_traffic_mac ON traffic_readings(mac);
CREATE INDEX idx_traffic_recorded_at ON traffic_readings(recorded_at);
CREATE INDEX idx_traffic_mac_recorded_at ON traffic_readings(mac, recorded_at);

-- Device snapshots table (for device metadata at poll time)
CREATE TABLE device_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mac VARCHAR(17) NOT NULL,
  recorded_at DATETIME NOT NULL,
  name VARCHAR(255),
  hostname VARCHAR(255),
  ip VARCHAR(45),
  interface VARCHAR(100),
  
  UNIQUE(mac, recorded_at)
);
```

### 2. New Files Structure

```
backend/
├── lib/
│   └── traffic_collector/
│       ├── collector.rb      # Main collection logic
│       ├── database.rb       # Database connection & migrations
│       └── scheduler.rb      # Scheduling logic (optional)
├── bin/
│   └── collect_traffic       # Executable script for cron/scheduler
├── db/
│   └── traffic_history.db    # SQLite database file (gitignored)
└── app.rb                    # Add new API endpoints
```

### 3. Traffic Collector Service

**Docker container with simple loop:**

```yaml
# docker-compose.yml addition
services:
  traffic-collector:
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: >
      sh -c "while true; do 
        bundle exec ruby bin/collect_traffic; 
        sleep 3600; 
      done"
    volumes:
      - ./backend:/app
      - traffic_data:/app/db
    environment:
      - KEENETIC_HOST=${KEENETIC_HOST}
      - KEENETIC_LOGIN=${KEENETIC_LOGIN}
      - KEENETIC_PASSWORD=${KEENETIC_PASSWORD}
    restart: unless-stopped

volumes:
  traffic_data:
```

### 4. Collection Logic

```ruby
# lib/traffic_collector/collector.rb
module TrafficCollector
  class Collector
    def collect
      devices = keenetic_client.devices.all
      recorded_at = Time.now.utc
      
      devices.each do |device|
        # Get previous reading to calculate delta
        previous = last_reading(device[:mac])
        
        rx_delta = calculate_delta(previous&.rxbytes, device[:rxbytes])
        tx_delta = calculate_delta(previous&.txbytes, device[:txbytes])
        
        insert_reading(
          mac: device[:mac],
          recorded_at: recorded_at,
          rxbytes: device[:rxbytes],
          txbytes: device[:txbytes],
          rx_delta: rx_delta,
          tx_delta: tx_delta,
          active: device[:active]
        )
        
        insert_snapshot(device, recorded_at)
      end
      
      cleanup_old_data  # Remove data older than retention period
    end
    
    private
    
    def calculate_delta(previous, current)
      return 0 if previous.nil?
      # Handle counter reset (device reconnected or router rebooted)
      current < previous ? current : current - previous
    end
  end
end
```

### 5. New API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/traffic/history/:mac` | Get traffic history for a device |
| `GET` | `/api/traffic/summary/:mac` | Get aggregated summary (daily/weekly/monthly) |
| `GET` | `/api/traffic/top` | Get top consumers for a time period |
| `GET` | `/api/traffic/stats` | Get overall traffic statistics |

**Example Response: `/api/traffic/history/AA:BB:CC:DD:EE:FF?period=7d`**

```json
{
  "mac": "AA:BB:CC:DD:EE:FF",
  "period": "7d",
  "readings": [
    {
      "recorded_at": "2026-01-06T10:00:00Z",
      "rxbytes": 1073741824,
      "txbytes": 536870912,
      "rx_delta": 52428800,
      "tx_delta": 26214400
    }
  ],
  "summary": {
    "total_rx": 367001600,
    "total_tx": 183500800,
    "avg_hourly_rx": 2184533,
    "avg_hourly_tx": 1092266
  }
}
```

### 6. Data Retention

- **Default retention**: 90 days
- **Aggregation strategy**:
  - Raw hourly data: 30 days
  - Daily aggregates: 1 year
  - Monthly aggregates: indefinite

### 7. Configuration

```ruby
# Environment variables
TRAFFIC_RETENTION_DAYS=90
TRAFFIC_POLL_INTERVAL=3600  # seconds (1 hour)
TRAFFIC_DB_PATH=/app/db/traffic_history.db
```

---

## Implementation Phases

### Phase 1: Database & Collection ⬜

- [ ] Add `sqlite3` gem to Gemfile
- [ ] Create `lib/traffic_collector/database.rb` with migrations
- [ ] Create `lib/traffic_collector/collector.rb` with collection logic
- [ ] Create `bin/collect_traffic` executable script
- [ ] Add `traffic-collector` service to docker-compose.yml
- [ ] Add `db/` directory to .gitignore

### Phase 2: API Endpoints ⬜

- [ ] Add `/api/traffic/history/:mac` endpoint
- [ ] Add `/api/traffic/summary/:mac` endpoint  
- [ ] Add `/api/traffic/top` endpoint
- [ ] Add `/api/traffic/stats` endpoint

### Phase 3: Frontend Integration ⬜

- [ ] Create `useTrafficHistory` hook
- [ ] Add traffic chart component
- [ ] Add traffic chart to device detail page
- [ ] Add traffic dashboard/overview page
- [ ] Add top consumers widget to main dashboard

### Phase 4: Data Management ⬜

- [ ] Implement automatic data retention cleanup
- [ ] Add daily/monthly aggregation for older data
- [ ] Add export functionality (CSV/JSON)

---

## Docker Volume Considerations

The SQLite database will be stored in a Docker volume to persist data across container restarts:

```yaml
volumes:
  traffic_data:
    driver: local
```

The database file will be at `/app/db/traffic_history.db` inside the container, mapped to the named volume `traffic_data`.

---

## Delta Calculation Edge Cases

1. **First reading**: No previous data → `delta = 0`
2. **Counter reset** (device reconnected): `current < previous` → `delta = current` (assume fresh start)
3. **Router reboot**: All counters reset → same handling as counter reset
4. **Device offline**: `active = false`, store zeros for deltas
5. **Missing poll** (collector was down): Calculate delta normally, but it will represent multiple hours

---

## Future Enhancements

- Real-time traffic monitoring (WebSocket updates)
- Traffic alerts (notify when device exceeds threshold)
- Per-interface traffic breakdown
- Bandwidth usage predictions
- Export to external time-series database (InfluxDB, Prometheus)

---

*Created: January 2026*

