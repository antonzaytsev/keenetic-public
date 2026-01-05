import { useQuery } from '@tanstack/react-query';
import { api, PortsResponse } from '../api';

export function usePorts() {
  return useQuery({
    queryKey: ['ports'],
    queryFn: () => api.get<PortsResponse>('/ports'),
    refetchInterval: 5000, // Auto-refresh every 5 seconds
  });
}

