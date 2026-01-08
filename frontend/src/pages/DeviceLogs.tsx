import { useMemo, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, Badge, Input, type Column } from '../components/ui';
import { useDeviceEvents, useDevices } from '../hooks';
import type { DeviceEvent } from '../api';
import './DeviceLogs.css';

function formatTime(timeStr: string | null, serverTime: string | null): string {
  if (!timeStr) return '-';
  try {
    const date = new Date(timeStr);
    if (isNaN(date.getTime())) return timeStr;
    
    // Use server time as reference for "today" comparison to handle timezone differences
    const serverDate = serverTime ? new Date(serverTime) : new Date();
    const isToday = date.toDateString() === serverDate.toDateString();
    const yesterday = new Date(serverDate);
    yesterday.setDate(yesterday.getDate() - 1);
    const isYesterday = date.toDateString() === yesterday.toDateString();
    
    // Format time in UTC to match the server's time display
    const hours = date.getUTCHours().toString().padStart(2, '0');
    const minutes = date.getUTCMinutes().toString().padStart(2, '0');
    const seconds = date.getUTCSeconds().toString().padStart(2, '0');
    const time = `${hours}:${minutes}:${seconds}`;
    
    if (isToday) return `Today ${time}`;
    if (isYesterday) return `Yesterday ${time}`;
    
    const month = date.toLocaleDateString('en-US', { month: 'short', timeZone: 'UTC' });
    const day = date.getUTCDate();
    return `${month} ${day}, ${hours}:${minutes}`;
  } catch {
    return timeStr;
  }
}

function formatRelativeTime(timeStr: string | null, serverTime: string | null): string {
  if (!timeStr || !serverTime) return '';
  try {
    const eventDate = new Date(timeStr);
    const serverDate = new Date(serverTime);
    if (isNaN(eventDate.getTime()) || isNaN(serverDate.getTime())) return '';
    
    // Use server time as reference to avoid timezone/clock differences
    const diff = serverDate.getTime() - eventDate.getTime();
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (seconds < 0) return ''; // Future event, skip
    if (seconds < 60) return 'just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;
    return '';
  } catch {
    return '';
  }
}

const TIME_RANGES = [
  { label: '1 hour', value: 3600 },
  { label: '6 hours', value: 21600 },
  { label: '24 hours', value: 86400 },
  { label: 'All', value: 0 },
];

const DEFAULT_TIME_RANGE = 3600;

export function DeviceLogs() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // Read filter values from URL params
  const sinceParam = searchParams.get('since');
  const timeRange = sinceParam !== null ? Number(sinceParam) : DEFAULT_TIME_RANGE;
  const selectedDevice = searchParams.get('device') || '';
  const filter = searchParams.get('q') || '';
  const typeFilter = (searchParams.get('type') as 'all' | 'connected' | 'disconnected') || 'all';

  // Update URL params helper - preserves existing params and only updates specified ones
  const updateParams = useCallback((updates: Record<string, string | null>) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev);
      for (const [key, value] of Object.entries(updates)) {
        if (value === null || value === '' || (key === 'since' && value === String(DEFAULT_TIME_RANGE)) || (key === 'type' && value === 'all')) {
          next.delete(key);
        } else {
          next.set(key, value);
        }
      }
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  // Filter setters that update URL
  const setTimeRange = useCallback((value: number) => {
    updateParams({ since: String(value) });
  }, [updateParams]);

  const setSelectedDevice = useCallback((value: string) => {
    updateParams({ device: value });
  }, [updateParams]);

  const setFilter = useCallback((value: string) => {
    updateParams({ q: value });
  }, [updateParams]);

  const setTypeFilter = useCallback((value: 'all' | 'connected' | 'disconnected') => {
    updateParams({ type: value });
  }, [updateParams]);

  const { data, isLoading, error } = useDeviceEvents({ since: timeRange });
  const { data: devicesData } = useDevices();

  // Normalize MAC address for consistent comparison
  const normalizeMac = (mac: string | null | undefined): string => {
    if (!mac) return '';
    return mac.toUpperCase().replace(/-/g, ':');
  };

  // Create a map of MAC to device name
  const deviceNameMap = useMemo(() => {
    const map = new Map<string, string>();
    devicesData?.devices.forEach((device) => {
      const name = device.name || device.hostname || device.mac;
      map.set(normalizeMac(device.mac), name);
    });
    return map;
  }, [devicesData?.devices]);

  // Get unique devices from events for the filter dropdown
  const devicesInLogs = useMemo(() => {
    const macs = new Set<string>();
    data?.events?.forEach((e) => {
      if (e.mac) macs.add(normalizeMac(e.mac));
    });
    return Array.from(macs).map((mac) => ({
      mac,
      name: deviceNameMap.get(mac) || mac,
    })).sort((a, b) => a.name.localeCompare(b.name));
  }, [data?.events, deviceNameMap]);

  // Reset selected device when it's no longer in the available options
  const validSelectedDevice = useMemo(() => {
    if (!selectedDevice) return '';
    const normalizedSelected = normalizeMac(selectedDevice);
    const exists = devicesInLogs.some(d => d.mac === normalizedSelected);
    return exists ? normalizedSelected : '';
  }, [selectedDevice, devicesInLogs]);

  const filteredEvents = useMemo(() => {
    let events = data?.events ?? [];
    
    // Filter by selected device (use validSelectedDevice for proper MAC matching)
    if (validSelectedDevice) {
      events = events.filter((e) => normalizeMac(e.mac) === validSelectedDevice);
    }
    
    // Filter by event type
    if (typeFilter !== 'all') {
      events = events.filter((e) => e.event_type === typeFilter);
    }
    
    // Filter by search term
    if (filter) {
      const search = filter.toLowerCase();
      events = events.filter((e) => {
        const deviceName = e.mac ? deviceNameMap.get(normalizeMac(e.mac)) : null;
        return (
          e.mac?.toLowerCase().includes(search) ||
          e.ip?.toLowerCase().includes(search) ||
          e.message?.toLowerCase().includes(search) ||
          deviceName?.toLowerCase().includes(search)
        );
      });
    }
    
    // Sort by time descending (newest first)
    // Parse times once and handle invalid/null times by putting them at the end
    events = [...events].sort((a, b) => {
      const timeA = a.time ? new Date(a.time).getTime() : NaN;
      const timeB = b.time ? new Date(b.time).getTime() : NaN;
      
      // Handle NaN cases - put invalid times at the end
      const validA = !isNaN(timeA);
      const validB = !isNaN(timeB);
      
      if (!validA && !validB) return 0;
      if (!validA) return 1;  // a goes after b
      if (!validB) return -1; // b goes after a
      
      return timeB - timeA; // Newest first
    });
    
    return events;
  }, [data?.events, filter, typeFilter, validSelectedDevice, deviceNameMap]);

  // Server timestamp for relative time calculation
  const serverTime = data?.timestamp ?? null;

  const columns: Column<DeviceEvent>[] = [
    {
      key: 'event_type',
      header: '',
      width: '10px',
      render: (event) => (
        <span className={`event-indicator ${event.event_type === 'connected' ? 'event-indicator--connected' : 'event-indicator--disconnected'}`}>
          {event.event_type === 'connected' ? '▲' : '▼'}
        </span>
      ),
    },
    {
      key: 'time',
      header: 'Time',
      width: '180px',
      render: (event) => (
        <div className="event-time">
          <span className="event-time__main">{formatTime(event.time, serverTime)}</span>
          <span className="event-time__relative">{formatRelativeTime(event.time, serverTime)}</span>
        </div>
      ),
    },
    {
      key: 'device',
      header: 'Device',
      render: (event) => {
        const deviceName = event.mac ? deviceNameMap.get(normalizeMac(event.mac)) : null;
        return (
          <div className="event-device">
            <span className="event-device__name">{deviceName || 'Unknown Device'}</span>
            {event.mac && (
              <span className="event-device__mac mono-text">{event.mac}</span>
            )}
          </div>
        );
      },
    },
    {
      key: 'connection',
      header: 'Connection',
      width: '160px',
      render: (event) => (
        <div className="event-connection">
          {event.band && <span className="event-band">{event.band}</span>}
          {event.details && <span className="event-details">{event.details}</span>}
          {!event.band && !event.details && <span className="mono-text--muted">-</span>}
        </div>
      ),
    },
    {
      key: 'reason',
      header: 'Details',
      width: '200px',
      render: (event) => (
        <span className={`event-reason ${event.reason ? '' : 'mono-text--muted'}`}>
          {event.reason || '-'}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      width: '130px',
      render: (event) => (
        <Badge 
          variant={event.event_type === 'connected' ? 'success' : 'danger'}
          size="sm"
        >
          {event.event_type === 'connected' ? 'Connected' : 'Disconnected'}
        </Badge>
      ),
    },
  ];

  return (
    <div className="device-logs-page">
      <Header
        title="Device Logs"
        subtitle={`${filteredEvents.length} events`}
      />

      {/* Filters */}
      <Card className="device-logs-filters" padding="sm">
        <div className="device-logs-filters__row">
          <select
            className="device-logs-filters__device"
            value={validSelectedDevice}
            onChange={(e) => setSelectedDevice(e.target.value)}
          >
            <option value="">All Devices</option>
            {devicesInLogs.map((device) => (
              <option key={device.mac} value={device.mac}>
                {device.name}
              </option>
            ))}
          </select>
          <Input
            placeholder="Search..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="device-logs-filters__search"
          />
          <div className="device-logs-filters__time">
            {TIME_RANGES.map((range) => (
              <button
                key={range.value}
                className={`time-filter-btn ${timeRange === range.value ? 'time-filter-btn--active' : ''}`}
                onClick={() => setTimeRange(range.value)}
              >
                {range.label}
              </button>
            ))}
          </div>
          <div className="device-logs-filters__type">
            <button
              className={`type-filter-btn ${typeFilter === 'all' ? 'type-filter-btn--active' : ''}`}
              onClick={() => setTypeFilter('all')}
            >
              All
            </button>
            <button
              className={`type-filter-btn type-filter-btn--connected ${typeFilter === 'connected' ? 'type-filter-btn--active' : ''}`}
              onClick={() => setTypeFilter('connected')}
            >
              ▲ Connected
            </button>
            <button
              className={`type-filter-btn type-filter-btn--disconnected ${typeFilter === 'disconnected' ? 'type-filter-btn--active' : ''}`}
              onClick={() => setTypeFilter('disconnected')}
            >
              ▼ Disconnected
            </button>
          </div>
        </div>
      </Card>

      {/* Events table */}
      <Card padding="none" className="device-logs-table-card">
        {error ? (
          <div className="device-logs-error">
            <p>Failed to load device logs</p>
            <span>{error.message}</span>
          </div>
        ) : (
          <Table
            columns={columns}
            data={filteredEvents}
            keyExtractor={(event, index) => `${index}-${event.time}-${event.mac}-${event.event_type}`}
            loading={isLoading}
            emptyMessage="No device events found"
            onRowClick={(event) => {
              if (event.mac) {
                navigate(`/devices/${encodeURIComponent(event.mac)}`);
              }
            }}
          />
        )}
      </Card>
    </div>
  );
}

