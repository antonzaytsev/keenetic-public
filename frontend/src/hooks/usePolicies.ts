import { useQuery } from '@tanstack/react-query';
import { api, PoliciesResponse, PolicyResponse } from '../api';

export function usePolicies() {
  return useQuery({
    queryKey: ['policies'],
    queryFn: () => api.get<PoliciesResponse>('/policies'),
    refetchInterval: 30000, // Refresh every 30 seconds
  });
}

export function usePolicy(id: string) {
  return useQuery({
    queryKey: ['policies', id],
    queryFn: () => api.get<PolicyResponse>(`/policies/${encodeURIComponent(id)}`),
    enabled: !!id,
  });
}

