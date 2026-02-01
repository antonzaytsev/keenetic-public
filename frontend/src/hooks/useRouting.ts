import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
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

interface CreateRouteParams {
  destination: string;
  mask: string;
  gateway?: string;
  interface?: string;
  metric?: number;
}

interface DeleteRouteParams {
  destination: string;
  mask: string;
}

export function useCreateRoute() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (params: CreateRouteParams) =>
      api.post<{ success: boolean }>('/routing/routes', params as Record<string, unknown>),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['routing', 'routes'] });
    },
  });
}

export function useDeleteRoute() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (params: DeleteRouteParams) =>
      api.delete<{ success: boolean }>('/routing/routes', params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['routing', 'routes'] });
    },
  });
}

