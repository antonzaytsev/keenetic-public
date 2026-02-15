import { useCallback, useState, useRef } from 'react';
import { Header } from '../components/layout';
import { Card, Progress, Chart, Table, Badge, Modal, type Column } from '../components/ui';
import { useSystemInfo, useSystemResources, useMeshMembers, useRebootRouter } from '../hooks';
import type { MeshMember } from '../api';
import './System.css';

const getApiBase = () => {
  const backendPort = import.meta.env.VITE_BACKEND_PORT;
  if (backendPort) {
    const { protocol, hostname } = window.location;
    return `${protocol}//${hostname}:${backendPort}/api`;
  }
  return '/api';
};

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
  const rebootMutation = useRebootRouter();
  
  // Backup/Restore state
  const [backupStatus, setBackupStatus] = useState<'idle' | 'downloading' | 'uploading' | 'success' | 'error'>('idle');
  const [backupMessage, setBackupMessage] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  // Reboot state
  const [rebootModalOpen, setRebootModalOpen] = useState(false);
  const [rebootTarget, setRebootTarget] = useState<{ id: string; name: string } | null>(null);
  const [rebootMessage, setRebootMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const openRebootModal = (nodeId: string, nodeName: string) => {
    setRebootTarget({ id: nodeId, name: nodeName });
    setRebootModalOpen(true);
    setRebootMessage(null);
  };

  const closeRebootModal = () => {
    setRebootModalOpen(false);
    setRebootTarget(null);
  };

  const handleReboot = async () => {
    if (!rebootTarget) return;
    
    // For now, we can only reboot the main router
    // Mesh node reboot would require direct API access to each node
    if (rebootTarget.id !== 'main') {
      setRebootMessage({ 
        type: 'error', 
        text: 'Restarting individual mesh nodes requires direct API access. Only the main router can be restarted from here.' 
      });
      return;
    }
    
    try {
      await rebootMutation.mutateAsync();
      setRebootMessage({ 
        type: 'success', 
        text: 'Router is rebooting. Please wait a few minutes for it to come back online.' 
      });
      setTimeout(() => {
        closeRebootModal();
      }, 2000);
    } catch (err) {
      setRebootMessage({ 
        type: 'error', 
        text: err instanceof Error ? err.message : 'Failed to reboot router' 
      });
    }
  };

  const getResourceData = useCallback(() => ({
    cpu: resources?.resources.cpu?.load_percent ?? 0,
    memory: resources?.resources.memory?.used_percent ?? 0,
  }), [resources]);

  const meshMembers = meshData?.members ?? [];

  const handleDownloadConfig = async () => {
    setBackupStatus('downloading');
    setBackupMessage(null);
    try {
      const response = await fetch(`${getApiBase()}/system/config`);
      if (!response.ok) {
        const error = await response.json().catch(() => ({ message: 'Download failed' }));
        throw new Error(error.message);
      }
      
      // Get filename from Content-Disposition header or generate one
      const disposition = response.headers.get('Content-Disposition');
      let filename = 'router-config.txt';
      if (disposition) {
        const match = disposition.match(/filename="?([^"]+)"?/);
        if (match) filename = match[1];
      }
      
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      
      setBackupStatus('success');
      setBackupMessage('Configuration downloaded successfully');
      setTimeout(() => setBackupStatus('idle'), 3000);
    } catch (err) {
      setBackupStatus('error');
      setBackupMessage(err instanceof Error ? err.message : 'Failed to download configuration');
    }
  };

  const handleUploadConfig = async (file: File) => {
    setBackupStatus('uploading');
    setBackupMessage(null);
    try {
      const content = await file.text();
      const response = await fetch(`${getApiBase()}/system/config`, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
        body: content,
      });
      
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.message || 'Upload failed');
      }
      
      setBackupStatus('success');
      setBackupMessage(result.message || 'Configuration uploaded successfully');
    } catch (err) {
      setBackupStatus('error');
      setBackupMessage(err instanceof Error ? err.message : 'Failed to upload configuration');
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleUploadConfig(file);
    }
    // Reset input so same file can be selected again
    e.target.value = '';
  };

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
    {
      key: 'actions',
      header: 'Actions',
      width: '100px',
      align: 'center',
      render: (node) => {
        const isController = node.mode === 'controller';
        const nodeKey = isController ? 'main' : node.id;
        const nodeName = node.name || node.model || 'Node';
        
        return (
          <button 
            className="mesh-restart-btn"
            onClick={() => openRebootModal(nodeKey, nodeName)}
            disabled={!node.online || rebootMutation.isPending}
            title={isController ? 'Restart controller' : 'Restart not available for extenders'}
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M23 4v6h-6" />
              <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
            </svg>
          </button>
        );
      },
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
          
          <div className="router-actions">
            <button 
              className="router-restart-btn"
              onClick={() => openRebootModal('main', systemInfo?.info?.model || 'Router')}
              disabled={rebootMutation.isPending}
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M23 4v6h-6" />
                <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
              </svg>
              Restart Router
            </button>
          </div>
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

        <Card title="Backup & Restore" className="backup-card">
          <div className="backup-content">
            <p className="backup-description">
              Download the router configuration for backup or restore from a previous backup.
            </p>
            <div className="backup-actions">
              <button 
                className="backup-btn backup-btn--download"
                onClick={handleDownloadConfig}
                disabled={backupStatus === 'downloading' || backupStatus === 'uploading'}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                {backupStatus === 'downloading' ? 'Downloading...' : 'Download Config'}
              </button>
              <button 
                className="backup-btn backup-btn--upload"
                onClick={() => fileInputRef.current?.click()}
                disabled={backupStatus === 'downloading' || backupStatus === 'uploading'}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="17 8 12 3 7 8" />
                  <line x1="12" y1="3" x2="12" y2="15" />
                </svg>
                {backupStatus === 'uploading' ? 'Uploading...' : 'Restore Config'}
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept=".txt,.conf"
                onChange={handleFileSelect}
                style={{ display: 'none' }}
              />
            </div>
            {backupMessage && (
              <div className={`backup-message backup-message--${backupStatus}`}>
                {backupMessage}
              </div>
            )}
          </div>
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

      {/* Reboot Confirmation Modal */}
      <Modal
        isOpen={rebootModalOpen}
        onClose={closeRebootModal}
        title="Restart Router"
        size="sm"
        footer={
          <div className="modal-footer-buttons">
            <button 
              className="modal-btn modal-btn--secondary"
              onClick={closeRebootModal}
              disabled={rebootMutation.isPending}
            >
              Cancel
            </button>
            <button 
              className="modal-btn modal-btn--danger"
              onClick={handleReboot}
              disabled={rebootMutation.isPending}
            >
              {rebootMutation.isPending ? 'Restarting...' : 'Restart'}
            </button>
          </div>
        }
      >
        <div className="modal-confirm">
          <div className="modal-confirm__icon modal-confirm__icon--warning">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
              <line x1="12" y1="9" x2="12" y2="13" />
              <line x1="12" y1="17" x2="12.01" y2="17" />
            </svg>
          </div>
          <p className="modal-confirm__message">
            Are you sure you want to restart <strong>{rebootTarget?.name}</strong>?
          </p>
          <p className="modal-confirm__detail">
            The router will be unavailable for a few minutes while it restarts. All connected devices will temporarily lose internet access.
          </p>
          {rebootMessage && (
            <div className={`reboot-message reboot-message--${rebootMessage.type}`}>
              {rebootMessage.text}
            </div>
          )}
        </div>
      </Modal>
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

