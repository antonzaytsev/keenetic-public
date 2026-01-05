import { useState, useCallback, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, Badge, Input, Toggle, type Column } from '../components/ui';
import { useDevices, usePolicies, useMeshMembers } from '../hooks';
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

function formatWifiBand(ap: string | null): string {
  if (!ap) return '';
  if (ap.includes('WifiMaster0')) return '2.4G';
  if (ap.includes('WifiMaster1')) return '5G';
  return '';
}

export function Devices() {
  const navigate = useNavigate();
  const { data, isLoading, error } = useDevices();
  const { data: policiesData } = usePolicies();
  const { data: meshData } = useMeshMembers();

  const [filter, setFilter] = useState('');
  const [showOnlyActive, setShowOnlyActive] = useState(false);

  // Create a map of policy ID to policy info for quick lookup
  const policyMap = useMemo(() => {
    const map = new Map<string, { id: string; name: string }>();
    policiesData?.policies.forEach((policy) => {
      map.set(policy.id, { id: policy.id, name: policy.name });
    });
    return map;
  }, [policiesData?.policies]);

  // Create a map of mesh node CID to node info for quick lookup
  const meshNodeMap = useMemo(() => {
    const map = new Map<string, { id: string; name: string | null }>();
    meshData?.members.forEach((member) => {
      map.set(member.id, { id: member.id, name: member.name });
    });
    return map;
  }, [meshData?.members]);

  // Get policy for a device by MAC address
  const getDevicePolicy = useCallback((mac: string) => {
    const policyId = policiesData?.device_assignments[mac];
    if (!policyId) return null;
    return policyMap.get(policyId) || { id: policyId, name: policyId };
  }, [policiesData?.device_assignments, policyMap]);

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

  const columns: Column<Device>[] = [
    {
      key: 'status',
      header: '',
      width: '10px',
      render: (device) => (
        <span className={`device-status-dot ${device.active ? 'device-status-dot--online' : ''}`} />
      ),
    },
    {
      key: 'name',
      header: 'Name',
      render: (device) => (
        <span className="device-name__value">
          {device.name || device.hostname || 'Unknown'}
        </span>
      ),
    },
    {
      key: 'ip',
      header: 'IP Address',
      render: (device) => (
        <span className="device-ip">
          <span className="mono-text">{device.ip || '-'}</span>
          {device.static_ip && (
            <svg className="device-ip__pin" viewBox="0 0 24 24" fill="currentColor" width="14" height="14">
              <path d="M16 12V4h1V2H7v2h1v8l-2 2v2h5.2v6h1.6v-6H18v-2l-2-2z"/>
            </svg>
          )}
        </span>
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
      key: 'wifi_ap',
      header: 'Connected To',
      render: (device) => {
        // For WiFi devices, show mesh node name + band
        if (device.wifi_ap && device.mws_cid) {
          const meshNode = meshNodeMap.get(device.mws_cid);
          const band = formatWifiBand(device.wifi_ap);
          const nodeName = meshNode?.name || 'Unknown';
          // Extract short name (first part before parenthesis)
          const shortName = nodeName.split('(')[0].trim().replace(/^Keenetic\s+/i, '');
          return (
            <span className="device-wifi">
              {shortName} {band && <span className="device-wifi__band">{band}</span>}
            </span>
          );
        }
        // WiFi but no mesh info - show controller
        if (device.wifi_ap) {
          const band = formatWifiBand(device.wifi_ap);
          return (
            <span className="device-wifi">
              Router {band && <span className="device-wifi__band">{band}</span>}
            </span>
          );
        }
        // Fallback to interface for wired devices
        const iface = device.interface;
        if (!iface) return '-';
        const ifaceName = typeof iface === 'string' ? iface : (iface.name || iface.id || '-');
        return <span className="device-wired">{ifaceName}</span>;
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
            onRowClick={(device) => navigate(`/devices/${encodeURIComponent(device.mac)}`)}
          />
        )}
      </Card>
    </div>
  );
}
