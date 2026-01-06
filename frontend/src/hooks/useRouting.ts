import { useQuery } from '@tanstack/react-query';
import { api, RoutesResponse, ArpResponse } from '../api';

export function useRoutes() {
  return useQuery({
    queryKey: ['routing', 'routes'],
    queryFn: () => api.get<RoutesResponse>('/routing/routes'),
    refetchInterval: 10000,
  });
}

export function useArpTable() {
  return useQuery({
    queryKey: ['routing', 'arp'],
    queryFn: () => api.get<ArpResponse>('/routing/arp'),
    refetchInterval: 10000,
  });
}

