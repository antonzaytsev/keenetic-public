import { useQuery } from '@tanstack/react-query';
import { api, DeviceEventsResponse } from '../api';

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

