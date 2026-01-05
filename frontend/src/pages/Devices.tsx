import { useState, useCallback, useMemo } from 'react';
import { Header } from '../components/layout';
import { Card, Table, StatusBadge, Badge, Input, Toggle, type Column } from '../components/ui';
import { useDevices, useUpdateDevice, usePolicies } from '../hooks';
import type { Device } from '../api';
import './Devices.css';

function formatBytes(bytes: number | null): string {
  if (bytes === null) return '-';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let value = bytes;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

export function Devices() {
  const { data, isLoading, error } = useDevices();
  const { data: policiesData } = usePolicies();
  const updateDevice = useUpdateDevice();
  
  const [filter, setFilter] = useState('');

  // Create a map of policy ID to policy info for quick lookup
  const policyMap = useMemo(() => {
    const map = new Map<string, { id: string; name: string }>();
    policiesData?.policies.forEach((policy) => {
      map.set(policy.id, { id: policy.id, name: policy.name });
    });
    return map;
  }, [policiesData?.policies]);

  // Get policy for a device by MAC address
  const getDevicePolicy = useCallback((mac: string) => {
    const policyId = policiesData?.device_assignments[mac];
    if (!policyId) return null;
    return policyMap.get(policyId) || { id: policyId, name: policyId };
  }, [policiesData?.device_assignments, policyMap]);
  const [showOnlyActive, setShowOnlyActive] = useState(false);
  const [editingDevice, setEditingDevice] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const filteredDevices = (data?.devices.filter((device) => {
    if (showOnlyActive && !device.active) return false;
    if (!filter) return true;
    
    const search = filter.toLowerCase();
    return (
      device.name?.toLowerCase().includes(search) ||
      device.hostname?.toLowerCase().includes(search) ||
      device.ip?.toLowerCase().includes(search) ||
      device.mac.toLowerCase().includes(search)
    );
  }) ?? []).sort((a, b) => {
    // First sort by active status (online first)
    if (a.active !== b.active) return a.active ? -1 : 1;
    // Then sort by name
    const nameA = (a.name || a.hostname || '').toLowerCase();
    const nameB = (b.name || b.hostname || '').toLowerCase();
    return nameA.localeCompare(nameB);
  });

  const startEditing = useCallback((device: Device) => {
    setEditingDevice(device.mac);
    setEditName(device.name || device.hostname || '');
  }, []);

  const saveEdit = useCallback(async () => {
    if (!editingDevice) return;
    
    await updateDevice.mutateAsync({ mac: editingDevice, name: editName });
    setEditingDevice(null);
    setEditName('');
  }, [editingDevice, editName, updateDevice]);

  const cancelEdit = useCallback(() => {
    setEditingDevice(null);
    setEditName('');
  }, []);

  const columns: Column<Device>[] = [
    {
      key: 'status',
      header: 'Status',
      width: '100px',
      render: (device) => <StatusBadge active={device.active} />,
    },
    {
      key: 'name',
      header: 'Name',
      render: (device) => {
        if (editingDevice === device.mac) {
          return (
            <div className="device-name-edit">
              <Input
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') saveEdit();
                  if (e.key === 'Escape') cancelEdit();
                }}
                autoFocus
              />
              <div className="device-name-edit__actions">
                <button className="btn btn--sm btn--primary" onClick={saveEdit}>
                  Save
                </button>
                <button className="btn btn--sm btn--ghost" onClick={cancelEdit}>
                  Cancel
                </button>
              </div>
            </div>
          );
        }
        return (
          <div className="device-name" onClick={() => startEditing(device)}>
            <span className="device-name__value">
              {device.name || device.hostname || 'Unknown'}
            </span>
            <span className="device-name__edit-icon">✎</span>
          </div>
        );
      },
    },
    {
      key: 'ip',
      header: 'IP Address',
      render: (device) => (
        <span className="mono-text">{device.ip || '-'}</span>
      ),
    },
    {
      key: 'mac',
      header: 'MAC Address',
      render: (device) => (
        <span className="mono-text mono-text--muted">{device.mac}</span>
      ),
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (device) => {
        const iface = device.interface;
        if (!iface) return '-';
        if (typeof iface === 'string') return iface;
        return iface.name || iface.id || '-';
      },
    },
    {
      key: 'policy',
      header: 'Policy',
      render: (device) => {
        const policy = getDevicePolicy(device.mac);
        if (!policy) {
          return <span className="device-policy device-policy--default">Default</span>;
        }
        return (
          <Badge variant="info" size="sm">
            {policy.name}
          </Badge>
        );
      },
    },
    {
      key: 'traffic',
      header: 'Traffic',
      align: 'right',
      render: (device) => (
        <div className="device-traffic">
          <span className="device-traffic__down">↓ {formatBytes(device.rxbytes)}</span>
          <span className="device-traffic__up">↑ {formatBytes(device.txbytes)}</span>
        </div>
      ),
    },
  ];

  return (
    <div className="devices-page">
      <Header 
        title="Devices" 
        subtitle={`${data?.count ?? 0} devices registered`}
      />

      <Card className="devices-filters" padding="sm">
        <div className="devices-filters__row">
          <Input
            placeholder="Search devices..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="devices-filters__search"
          />
          <Toggle
            checked={showOnlyActive}
            onChange={setShowOnlyActive}
            label="Active only"
          />
        </div>
      </Card>

      <Card padding="none" className="devices-table-card">
        {error ? (
          <div className="devices-error">
            <p>Failed to load devices</p>
            <span>{error.message}</span>
          </div>
        ) : (
          <Table
            columns={columns}
            data={filteredDevices}
            keyExtractor={(device) => device.mac}
            loading={isLoading}
            emptyMessage="No devices match your filters"
          />
        )}
      </Card>
    </div>
  );
}

