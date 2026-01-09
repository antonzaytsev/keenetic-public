import { useQuery } from '@tanstack/react-query';
import { api, DeviceEventsResponse, LogsResponse } from '../api';

interface UseDeviceEventsOptions {
  mac?: string;
  since?: number; // seconds, default 3600 (1 hour), 0 for all
}

export function useDeviceEvents(options: UseDeviceEventsOptions = {}) {
  const { mac, since = 3600 } = options;
  
  return useQuery({
    queryKey: ['device-events', mac, since],
    queryFn: () => {
      const params = new URLSearchParams();
      if (mac) params.set('mac', mac);
      if (since !== undefined) params.set('since', since.toString());
      const queryString = params.toString();
      return api.get<DeviceEventsResponse>(`/logs/device-events${queryString ? `?${queryString}` : ''}`);
    },
    refetchInterval: 30000, // Refresh every 30 seconds
  });
}

interface UseSystemLogsOptions {
  limit?: number;
}

export function useSystemLogs(options: UseSystemLogsOptions = {}) {
  const { limit } = options;
  
  return useQuery({
    queryKey: ['system-logs', limit],
    queryFn: () => {
      const params = new URLSearchParams();
      if (limit) params.set('limit', limit.toString());
      const queryString = params.toString();
      return api.get<LogsResponse>(`/logs${queryString ? `?${queryString}` : ''}`);
    },
    refetchInterval: 10000, // Refresh every 10 seconds for real-time feel
  });
}

