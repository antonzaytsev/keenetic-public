import { useCallback } from 'react';
import { Header } from '../components/layout';
import { Card, Table, ConnectionBadge, Progress, Badge, Chart, type Column } from '../components/ui';
import { useSystemInfo, useSystemResources, useNetworkInterfaces } from '../hooks';
import type { NetworkInterface } from '../api';
import './System.css';

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

export function System() {
  const { data: systemInfo, isLoading: infoLoading } = useSystemInfo();
  const { data: resources } = useSystemResources();
  const { data: interfaces, isLoading: interfacesLoading } = useNetworkInterfaces();

  const getResourceData = useCallback(() => ({
    cpu: resources?.resources.cpu?.load_percent ?? 0,
    memory: resources?.resources.memory?.used_percent ?? 0,
  }), [resources]);

  const interfaceColumns: Column<NetworkInterface>[] = [
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

  return (
    <div className="system-page">
      <Header 
        title="System" 
        subtitle="Router information and network interfaces"
      />

      {/* System Info */}
      <div className="system-grid">
        <Card title="Router Information" className="info-card">
          {infoLoading ? (
            <div className="info-loading">Loading...</div>
          ) : systemInfo?.info ? (
            <div className="info-list">
              <InfoRow label="Model" value={systemInfo.info.model} />
              <InfoRow label="Device" value={systemInfo.info.device} />
              <InfoRow label="Manufacturer" value={systemInfo.info.manufacturer} />
              <InfoRow label="Hardware Version" value={systemInfo.info.hw_version} />
              <InfoRow label="Architecture" value={systemInfo.info.arch} />
            </div>
          ) : (
            <div className="info-empty">No information available</div>
          )}
        </Card>

        <Card title="Firmware" className="firmware-card">
          {systemInfo?.info ? (
            <div className="info-list">
              <InfoRow label="Firmware" value={systemInfo.info.firmware} />
              <InfoRow label="Version" value={systemInfo.info.firmware_version} highlight />
              <InfoRow label="NDM Version" value={systemInfo.info.ndm_version} />
              <InfoRow label="NDW Version" value={systemInfo.info.ndw_version} />
            </div>
          ) : (
            <div className="info-empty">No information available</div>
          )}
        </Card>

        <Card title="Resource Usage" className="resource-card">
          {resources?.resources && (
            <div className="resource-bars">
              <Progress
                value={resources.resources.cpu?.load_percent ?? 0}
                label="CPU"
                size="md"
              />
              <Progress
                value={resources.resources.memory?.used_percent ?? 0}
                label="Memory"
                size="md"
              />
              {resources.resources.swap && resources.resources.swap.total > 0 && (
                <Progress
                  value={resources.resources.swap.used_percent}
                  label="Swap"
                  size="md"
                />
              )}
              <div className="resource-uptime">
                <span className="resource-uptime__label">System Uptime</span>
                <span className="resource-uptime__value">
                  {formatUptime(resources.resources.uptime)}
                </span>
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Resource History Chart */}
      <Card title="Resource Usage History" className="chart-card">
        <Chart
          series={[
            { key: 'cpu', label: 'CPU', color: '#22c55e' },
            { key: 'memory', label: 'Memory', color: '#3b82f6' },
          ]}
          getData={getResourceData}
          maxPoints={60}
          height={220}
          refreshInterval={3000}
        />
      </Card>

      {/* Interfaces */}
      <Card title="Network Interfaces" padding="none" className="interfaces-card">
        <Table
          columns={interfaceColumns}
          data={interfaces?.interfaces ?? []}
          keyExtractor={(iface) => iface.id}
          loading={interfacesLoading}
          emptyMessage="No interfaces found"
        />
      </Card>
    </div>
  );
}

function InfoRow({ 
  label, 
  value, 
  highlight = false 
}: { 
  label: string; 
  value: string | null; 
  highlight?: boolean;
}) {
  return (
    <div className="info-row">
      <span className="info-row__label">{label}</span>
      <span className={`info-row__value ${highlight ? 'info-row__value--highlight' : ''}`}>
        {value || '-'}
      </span>
    </div>
  );
}

