import { useQuery } from '@tanstack/react-query';
import { api, InternetStatusResponse, InternetSpeedResponse } from '../api';

export function useInternetStatus() {
  return useQuery({
    queryKey: ['internet', 'status'],
    queryFn: () => api.get<InternetStatusResponse>('/internet/status'),
    refetchInterval: 5000, // Auto-refresh every 5 seconds
  });
}

export function useInternetSpeed() {
  return useQuery({
    queryKey: ['internet', 'speed'],
    queryFn: () => api.get<InternetSpeedResponse>('/internet/speed'),
    refetchInterval: 3000, // Auto-refresh every 3 seconds for live stats
  });
}

