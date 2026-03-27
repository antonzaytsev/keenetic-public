import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../api';
import type { DomainGroupsResponse, DnsRoutesResponse } from '../api';

export function useDomainGroups() {
  return useQuery({
    queryKey: ['dns-routes', 'domain-groups'],
    queryFn: () => api.get<DomainGroupsResponse>('/dns-routes/domain-groups'),
    refetchInterval: 30000,
  });
}

export function useDnsRoutes() {
  return useQuery({
    queryKey: ['dns-routes', 'routes'],
    queryFn: () => api.get<DnsRoutesResponse>('/dns-routes/routes'),
    refetchInterval: 30000,
  });
}

interface CreateDomainGroupParams {
  name: string;
  description: string;
  domains: string[];
}

export function useCreateDomainGroup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: CreateDomainGroupParams) =>
      api.post<{ success: boolean }>('/dns-routes/domain-groups', params as unknown as Record<string, unknown>),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'domain-groups'] });
    },
  });
}

export function useDeleteDomainGroup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (name: string) =>
      api.delete<{ success: boolean }>(`/dns-routes/domain-groups/${encodeURIComponent(name)}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'domain-groups'] });
    },
  });
}

interface AddDnsRouteParams {
  group: string;
  interface: string;
  comment?: string;
}

export function useAddDnsRoute() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: AddDnsRouteParams) =>
      api.post<{ success: boolean }>('/dns-routes/routes', params as unknown as Record<string, unknown>),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'routes'] });
    },
  });
}

export function useDeleteDnsRoute() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (index: string) =>
      api.delete<{ success: boolean }>(`/dns-routes/routes/${encodeURIComponent(index)}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'routes'] });
    },
  });
}
