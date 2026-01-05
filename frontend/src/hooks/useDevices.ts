import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api, DevicesResponse, DeviceResponse } from '../api';

export function useDevices() {
  return useQuery({
    queryKey: ['devices'],
    queryFn: () => api.get<DevicesResponse>('/devices'),
    refetchInterval: 5000, // Auto-refresh every 5 seconds
  });
}

export function useDevice(mac: string) {
  return useQuery({
    queryKey: ['devices', mac],
    queryFn: () => api.get<DeviceResponse>(`/devices/${encodeURIComponent(mac)}`),
    enabled: !!mac,
  });
}

export function useUpdateDevice() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ mac, ...data }: { mac: string; name?: string; access?: string }) =>
      api.patch(`/devices/${encodeURIComponent(mac)}`, data),
    onMutate: async ({ mac, name }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['devices'] });

      // Snapshot previous value
      const previousDevices = queryClient.getQueryData<DevicesResponse>(['devices']);

      // Optimistically update
      if (previousDevices && name !== undefined) {
        queryClient.setQueryData<DevicesResponse>(['devices'], {
          ...previousDevices,
          devices: previousDevices.devices.map((device) =>
            device.mac === mac ? { ...device, name } : device
          ),
        });
      }

      return { previousDevices };
    },
    onError: (_err, _variables, context) => {
      // Rollback on error
      if (context?.previousDevices) {
        queryClient.setQueryData(['devices'], context.previousDevices);
      }
    },
    onSettled: () => {
      // Refetch after mutation
      queryClient.invalidateQueries({ queryKey: ['devices'] });
    },
  });
}

