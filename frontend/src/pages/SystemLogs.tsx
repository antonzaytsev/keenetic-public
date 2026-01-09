import { useMemo, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, Badge, Input, type Column } from '../components/ui';
import { useSystemLogs } from '../hooks';
import type { LogEntry } from '../api';
import './SystemLogs.css';

function formatTime(timeStr: string | null, serverTime: string | null): string {
  if (!timeStr) return '-';
  try {
    const date = new Date(timeStr);
    if (isNaN(date.getTime())) return timeStr;
    
    const serverDate = serverTime ? new Date(serverTime) : new Date();
    const isToday = date.toDateString() === serverDate.toDateString();
    const yesterday = new Date(serverDate);
    yesterday.setDate(yesterday.getDate() - 1);
    const isYesterday = date.toDateString() === yesterday.toDateString();
    
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
    
    const diff = serverDate.getTime() - eventDate.getTime();
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (seconds < 0) return '';
    if (seconds < 60) return 'just now';
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;
    return '';
  } catch {
    return '';
  }
}

const LOG_LEVELS = ['all', 'info', 'warning', 'error', 'debug'] as const;
type LogLevel = typeof LOG_LEVELS[number];

const TIME_RANGES = [
  { label: '10 min', value: 600 },
  { label: '30 min', value: 1800 },
  { label: '1 hour', value: 3600 },
] as const;

const DEFAULT_TIME_RANGE = 600; // 10 minutes
const PAGE_SIZE = 50;

function getLevelVariant(level: string | null): 'success' | 'warning' | 'danger' | 'info' | 'default' {
  switch (level?.toLowerCase()) {
    case 'error':
      return 'danger';
    case 'warning':
      return 'warning';
    case 'info':
      return 'info';
    case 'debug':
      return 'default';
    default:
      return 'default';
  }
}

export function SystemLogs() {
  const [searchParams, setSearchParams] = useSearchParams();

  // Read filter values from URL params
  const levelFilter = (searchParams.get('level') as LogLevel) || 'all';
  const filter = searchParams.get('q') || '';
  const facilityFilter = searchParams.get('facility') || '';
  const sinceParam = searchParams.get('since');
  const timeRange = sinceParam !== null ? Number(sinceParam) : DEFAULT_TIME_RANGE;
  const pageParam = searchParams.get('page');
  const currentPage = pageParam !== null ? Math.max(1, Number(pageParam)) : 1;

  // Update URL params helper
  const updateParams = useCallback((updates: Record<string, string | null>) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev);
      for (const [key, value] of Object.entries(updates)) {
        if (value === null || value === '' || 
            (key === 'level' && value === 'all') ||
            (key === 'since' && value === String(DEFAULT_TIME_RANGE)) ||
            (key === 'page' && value === '1')) {
          next.delete(key);
        } else {
          next.set(key, value);
        }
      }
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  // Filter setters
  const setLevelFilter = useCallback((value: LogLevel) => {
    updateParams({ level: value, page: '1' }); // Reset to page 1 on filter change
  }, [updateParams]);

  const setFilter = useCallback((value: string) => {
    updateParams({ q: value, page: '1' });
  }, [updateParams]);

  const setFacilityFilter = useCallback((value: string) => {
    updateParams({ facility: value, page: '1' });
  }, [updateParams]);

  const setTimeRange = useCallback((value: number) => {
    updateParams({ since: String(value), page: '1' });
  }, [updateParams]);

  const setPage = useCallback((value: number) => {
    updateParams({ page: String(value) });
  }, [updateParams]);

  const { data, isLoading, error } = useSystemLogs();

  // Get unique facilities for filter dropdown
  const facilities = useMemo(() => {
    const facilitySet = new Set<string>();
    data?.logs?.forEach((log) => {
      if (log.facility) facilitySet.add(log.facility);
    });
    return Array.from(facilitySet).sort();
  }, [data?.logs]);

  const serverTime = data?.timestamp ?? null;

  // Filter logs by all criteria including time
  const filteredLogs = useMemo(() => {
    let logs = data?.logs ?? [];
    
    // Filter by time range using server time as reference
    if (timeRange > 0 && serverTime) {
      const serverDate = new Date(serverTime);
      const cutoffTime = serverDate.getTime() - (timeRange * 1000);
      logs = logs.filter((log) => {
        if (!log.time) return false;
        const logTime = new Date(log.time).getTime();
        return !isNaN(logTime) && logTime >= cutoffTime;
      });
    }
    
    // Filter by level
    if (levelFilter !== 'all') {
      logs = logs.filter((log) => log.level?.toLowerCase() === levelFilter);
    }
    
    // Filter by facility
    if (facilityFilter) {
      logs = logs.filter((log) => log.facility === facilityFilter);
    }
    
    // Filter by search term
    if (filter) {
      const search = filter.toLowerCase();
      logs = logs.filter((log) => (
        log.message?.toLowerCase().includes(search) ||
        log.facility?.toLowerCase().includes(search) ||
        log.level?.toLowerCase().includes(search)
      ));
    }
    
    // Sort by time descending (newest first)
    logs = [...logs].sort((a, b) => {
      const timeA = a.time ? new Date(a.time).getTime() : NaN;
      const timeB = b.time ? new Date(b.time).getTime() : NaN;
      
      const validA = !isNaN(timeA);
      const validB = !isNaN(timeB);
      
      if (!validA && !validB) return 0;
      if (!validA) return 1;
      if (!validB) return -1;
      
      return timeB - timeA;
    });
    
    return logs;
  }, [data?.logs, filter, levelFilter, facilityFilter, timeRange, serverTime]);

  // Pagination
  const totalPages = Math.ceil(filteredLogs.length / PAGE_SIZE);
  const validCurrentPage = Math.min(currentPage, Math.max(1, totalPages));
  const paginatedLogs = useMemo(() => {
    const start = (validCurrentPage - 1) * PAGE_SIZE;
    return filteredLogs.slice(start, start + PAGE_SIZE);
  }, [filteredLogs, validCurrentPage]);

  const columns: Column<LogEntry>[] = [
    {
      key: 'level',
      header: '',
      width: '8px',
      render: (log) => (
        <span className={`log-level-indicator log-level-indicator--${log.level?.toLowerCase() || 'unknown'}`} />
      ),
    },
    {
      key: 'time',
      header: 'Time',
      width: '170px',
      render: (log) => (
        <div className="log-time">
          <span className="log-time__main">{formatTime(log.time, serverTime)}</span>
          <span className="log-time__relative">{formatRelativeTime(log.time, serverTime)}</span>
        </div>
      ),
    },
    {
      key: 'log_level',
      header: 'Level',
      width: '90px',
      render: (log) => (
        <Badge 
          variant={getLevelVariant(log.level)}
          size="sm"
        >
          {log.level?.toUpperCase() || 'UNKNOWN'}
        </Badge>
      ),
    },
    {
      key: 'facility',
      header: 'Facility',
      width: '140px',
      render: (log) => (
        <span className="log-facility">{log.facility || '-'}</span>
      ),
    },
    {
      key: 'message',
      header: 'Message',
      render: (log) => (
        <span className="log-message">{log.message || '-'}</span>
      ),
    },
  ];

  return (
    <div className="system-logs-page">
      <Header
        title="System Logs"
        subtitle={`${filteredLogs.length} log entries`}
      />

      {/* Filters */}
      <Card className="system-logs-filters" padding="sm">
        <div className="system-logs-filters__row">
          <div className="system-logs-filters__time">
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

          <div className="system-logs-filters__levels">
            {LOG_LEVELS.map((level) => (
              <button
                key={level}
                className={`level-filter-btn level-filter-btn--${level} ${levelFilter === level ? 'level-filter-btn--active' : ''}`}
                onClick={() => setLevelFilter(level)}
              >
                {level === 'all' ? 'All' : level.charAt(0).toUpperCase() + level.slice(1)}
              </button>
            ))}
          </div>
          
          <select
            className="system-logs-filters__facility"
            value={facilityFilter}
            onChange={(e) => setFacilityFilter(e.target.value)}
          >
            <option value="">All Facilities</option>
            {facilities.map((facility) => (
              <option key={facility} value={facility}>
                {facility}
              </option>
            ))}
          </select>
          
          <Input
            placeholder="Search logs..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="system-logs-filters__search"
          />
        </div>
      </Card>

      {/* Logs table */}
      <Card padding="none" className="system-logs-table-card">
        {error ? (
          <div className="system-logs-error">
            <p>Failed to load system logs</p>
            <span>{error.message}</span>
          </div>
        ) : (
          <Table
            columns={columns}
            data={paginatedLogs}
            keyExtractor={(log, index) => `${index}-${log.time}-${log.facility}`}
            loading={isLoading}
            emptyMessage="No log entries found"
          />
        )}
      </Card>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="system-logs-pagination">
          <button
            className="pagination-btn"
            onClick={() => setPage(1)}
            disabled={validCurrentPage === 1}
          >
            ««
          </button>
          <button
            className="pagination-btn"
            onClick={() => setPage(validCurrentPage - 1)}
            disabled={validCurrentPage === 1}
          >
            «
          </button>
          
          <span className="pagination-info">
            Page {validCurrentPage} of {totalPages}
          </span>
          
          <button
            className="pagination-btn"
            onClick={() => setPage(validCurrentPage + 1)}
            disabled={validCurrentPage === totalPages}
          >
            »
          </button>
          <button
            className="pagination-btn"
            onClick={() => setPage(totalPages)}
            disabled={validCurrentPage === totalPages}
          >
            »»
          </button>
        </div>
      )}
    </div>
  );
}

