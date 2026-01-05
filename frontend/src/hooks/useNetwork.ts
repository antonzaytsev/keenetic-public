import { useQuery } from '@tanstack/react-query';
import { api, InterfacesResponse, AccessPointsResponse } from '../api';

export function useNetworkInterfaces() {
  return useQuery({
    queryKey: ['network', 'interfaces'],
    queryFn: () => api.get<InterfacesResponse>('/network/interfaces'),
    refetchInterval: 5000,
  });
}

export function useWifiAccessPoints() {
  return useQuery({
    queryKey: ['wifi', 'access-points'],
    queryFn: () => api.get<AccessPointsResponse>('/wifi/access-points'),
    refetchInterval: 10000,
  });
}

