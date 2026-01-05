import { Header } from '../components/layout';
import { Card, Table, ConnectionBadge, Badge, type Column } from '../components/ui';
import { useNetworkInterfaces } from '../hooks';
import type { NetworkInterface } from '../api';
import './Interfaces.css';

function formatBytes(bytes: number | null): string {
  if (bytes === null) return '-';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let value = bytes;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(2)} ${units[i]}`;
}

function formatUptime(seconds: number | null): string {
  if (!seconds) return 'N/A';
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  
  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (mins > 0) parts.push(`${mins}m`);
  if (secs > 0 && days === 0) parts.push(`${secs}s`);
  
  return parts.join(' ') || '0s';
}

export function Interfaces() {
  const { data: interfaces, isLoading } = useNetworkInterfaces();

  const columns: Column<NetworkInterface>[] = [
    {
      key: 'status',
      header: 'Status',
      width: '100px',
      render: (iface) => (
        <ConnectionBadge connected={iface.connected} />
      ),
    },
    {
      key: 'id',
      header: 'Interface',
      render: (iface) => (
        <div className="interface-name">
          <span className="interface-name__id">{iface.id}</span>
          {iface.description && (
            <span className="interface-name__desc">{iface.description}</span>
          )}
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (iface) => (
        <Badge variant={iface.defaultgw ? 'info' : 'neutral'} size="sm">
          {iface.type || 'unknown'}
        </Badge>
      ),
    },
    {
      key: 'address',
      header: 'IP Address',
      render: (iface) => (
        <span className="mono-text">{iface.address || '-'}</span>
      ),
    },
    {
      key: 'mac',
      header: 'MAC',
      render: (iface) => (
        <span className="mono-text mono-text--muted">{iface.mac || '-'}</span>
      ),
    },
    {
      key: 'traffic',
      header: 'Traffic',
      align: 'right',
      render: (iface) => (
        <div className="interface-traffic">
          <span className="interface-traffic__rx">↓ {formatBytes(iface.rxbytes)}</span>
          <span className="interface-traffic__tx">↑ {formatBytes(iface.txbytes)}</span>
        </div>
      ),
    },
    {
      key: 'uptime',
      header: 'Uptime',
      align: 'right',
      render: (iface) => (
        <span className="mono-text--muted">{formatUptime(iface.uptime)}</span>
      ),
    },
  ];

  const connectedCount = interfaces?.interfaces.filter(i => i.connected).length ?? 0;

  return (
    <div className="interfaces-page">
      <Header
        title="Network Interfaces"
        subtitle={`${connectedCount} of ${interfaces?.count ?? 0} interfaces connected`}
      />

      <Card padding="none" className="interfaces-table-card">
        <Table
          columns={columns}
          data={interfaces?.interfaces ?? []}
          keyExtractor={(iface) => iface.id}
          loading={isLoading}
          emptyMessage="No interfaces found"
        />
      </Card>
    </div>
  );
}

