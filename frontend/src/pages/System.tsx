import { useCallback } from 'react';
import { Header } from '../components/layout';
import { Card, Progress, Chart, Table, Badge, type Column } from '../components/ui';
import { useSystemInfo, useSystemResources, useMeshMembers } from '../hooks';
import type { MeshMember } from '../api';
import './System.css';

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

function formatConnection(via: string | null): string {
  if (!via) return '-';
  if (via === 'Ethernet' || via.includes('Ethernet')) return '🔌 Ethernet';
  if (via.includes('WifiMaster0')) return '📶 2.4 GHz';
  if (via.includes('WifiMaster1')) return '📶 5 GHz';
  return via;
}

export function System() {
  const { data: systemInfo, isLoading: infoLoading } = useSystemInfo();
  const { data: resources } = useSystemResources();
  const { data: meshData, isLoading: meshLoading } = useMeshMembers();

  const getResourceData = useCallback(() => ({
    cpu: resources?.resources.cpu?.load_percent ?? 0,
    memory: resources?.resources.memory?.used_percent ?? 0,
  }), [resources]);

  const meshMembers = meshData?.members ?? [];

  const meshColumns: Column<MeshMember>[] = [
    {
      key: 'status',
      header: 'Status',
      width: '80px',
      render: (node) => (
        <Badge variant={node.online ? 'success' : 'neutral'} dot size="sm">
          {node.online ? 'Online' : 'Offline'}
        </Badge>
      ),
    },
    {
      key: 'name',
      header: 'Node Name',
      render: (node) => (
        <div className="mesh-node-name">
          <span className="mesh-node-name__text">{node.name || 'Unknown'}</span>
          <span className="mesh-node-name__model">{node.model}</span>
        </div>
      ),
    },
    {
      key: 'mode',
      header: 'Role',
      render: (node) => (
        <Badge variant={node.mode === 'controller' ? 'info' : 'neutral'} size="sm">
          {node.mode === 'controller' ? 'Controller' : 'Extender'}
        </Badge>
      ),
    },
    {
      key: 'clients',
      header: 'Clients',
      align: 'center',
      render: (node) => (
        <span className="mesh-clients">{node.clients_count ?? 0}</span>
      ),
    },
    {
      key: 'uptime',
      header: 'Uptime',
      render: (node) => (
        <span className="mesh-uptime">{formatUptime(node.uptime)}</span>
      ),
    },
    {
      key: 'ip',
      header: 'IP Address',
      render: (node) => (
        <span className="mesh-ip">{node.ip || '-'}</span>
      ),
    },
    {
      key: 'via',
      header: 'Connection',
      render: (node) => (
        <span className="mesh-via">{formatConnection(node.via)}</span>
      ),
    },
    {
      key: 'version',
      header: 'Version',
      render: (node) => (
        <span className="mesh-version">{node.version || '-'}</span>
      ),
    },
  ];

  return (
    <div className="system-page">
      <Header 
        title="System" 
        subtitle="Router information and resource usage"
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

      {/* Mesh Wi-Fi System */}
      <Card title="Mesh Wi-Fi System" className="mesh-card" padding="none">
        {meshLoading ? (
          <div className="info-loading">Loading mesh network...</div>
        ) : meshMembers.length > 0 ? (
          <Table
            columns={meshColumns}
            data={meshMembers}
            keyExtractor={(node, index) => `${index}-${node.id}`}
          />
        ) : (
          <div className="info-empty">No mesh network configured</div>
        )}
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

