import { useQuery } from '@tanstack/react-query';
import { api, ResourcesResponse, SystemInfoResponse } from '../api';

export function useSystemResources() {
  return useQuery({
    queryKey: ['system', 'resources'],
    queryFn: () => api.get<ResourcesResponse>('/system/resources'),
    refetchInterval: 3000, // Auto-refresh every 3 seconds for live stats
  });
}

export function useSystemInfo() {
  return useQuery({
    queryKey: ['system', 'info'],
    queryFn: () => api.get<SystemInfoResponse>('/system/info'),
    staleTime: 60000, // System info rarely changes, cache for 1 minute
  });
}

