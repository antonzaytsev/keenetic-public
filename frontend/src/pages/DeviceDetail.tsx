import { useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, StatusBadge, Badge } from '../components/ui';
import { useDevice, useUpdateDevice, usePolicies } from '../hooks';
import './DeviceDetail.css';

function formatBytes(bytes: number | null): string {
  if (bytes === null) return '-';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let value = bytes;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

function formatUptime(seconds: number | null): string {
  if (!seconds) return '-';
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  
  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (mins > 0) parts.push(`${mins}m`);
  
  return parts.join(' ') || '< 1m';
}

function formatDateTime(dateStr: string | null): string {
  if (!dateStr) return '-';
  try {
    const date = new Date(dateStr);
    return date.toLocaleString();
  } catch {
    return dateStr;
  }
}

export function DeviceDetail() {
  const { mac } = useParams<{ mac: string }>();
  const navigate = useNavigate();
  const { data, isLoading, error, refetch } = useDevice(mac || '');
  const { data: policiesData } = usePolicies();
  const updateDevice = useUpdateDevice();

  const device = data?.device;

  const handleNameEdit = useCallback(async (e: React.FocusEvent<HTMLSpanElement> | React.KeyboardEvent<HTMLSpanElement>) => {
    if ('key' in e && e.key !== 'Enter') return;
    if ('key' in e) e.preventDefault();
    
    const newName = (e.target as HTMLSpanElement).textContent?.trim() || '';
    const currentName = device?.name || '';
    
    if (newName !== currentName && mac) {
      await updateDevice.mutateAsync({ mac, name: newName });
      refetch();
    }
  }, [device?.name, mac, updateDevice, refetch]);

  const handleNameKeyDown = useCallback((e: React.KeyboardEvent<HTMLSpanElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      (e.target as HTMLSpanElement).blur();
    }
    if (e.key === 'Escape') {
      (e.target as HTMLSpanElement).textContent = device?.name || '-';
      (e.target as HTMLSpanElement).blur();
    }
  }, [device?.name]);

  // Get policy for this device
  const getDevicePolicy = () => {
    if (!mac || !policiesData) return null;
    const policyId = policiesData.device_assignments[mac];
    if (!policyId) return null;
    const policy = policiesData.policies.find(p => p.id === policyId);
    return policy || { id: policyId, name: policyId };
  };

  const policy = getDevicePolicy();

  const getInterfaceDisplay = () => {
    if (!device?.interface) return '-';
    if (typeof device.interface === 'string') return device.interface;
    return device.interface.name || device.interface.id || '-';
  };

  if (isLoading) {
    return (
      <div className="device-detail-page">
        <Header title="Device Details" subtitle="Loading..." />
        <div className="device-detail-loading">
          <div className="loading-spinner" />
          <p>Loading device information...</p>
        </div>
      </div>
    );
  }

  if (error || !device) {
    return (
      <div className="device-detail-page">
        <Header title="Device Details" subtitle="Error" />
        <Card className="device-detail-error">
          <div className="error-icon">⚠</div>
          <h3>Device Not Found</h3>
          <p>{error?.message || 'The requested device could not be found.'}</p>
          <button className="btn btn--primary" onClick={() => navigate('/devices')}>
            Back to Devices
          </button>
        </Card>
      </div>
    );
  }

  return (
    <div className="device-detail-page">
      <div className="device-detail-header">
        <button className="back-button" onClick={() => navigate('/devices')}>
          <span className="back-button__icon">←</span>
          <span className="back-button__text">Back to Devices</span>
        </button>
      </div>

      <Header 
        title={device.name || device.hostname || 'Unknown Device'}
        subtitle={device.mac}
      />

      <div className="device-detail-status">
        <StatusBadge active={device.active} />
        {device.registered && (
          <Badge variant="info" size="sm">Registered</Badge>
        )}
        {policy && (
          <Badge variant="warning" size="sm">Policy: {policy.name}</Badge>
        )}
      </div>

      <div className="device-detail-grid">
        {/* Network Information */}
        <Card title="Network Information" className="detail-card">
          <div className="info-list">
            <InfoRow label="IP Address" value={device.ip} mono />
            <InfoRow label="MAC Address" value={device.mac} mono />
            <InfoRow label="Interface" value={getInterfaceDisplay()} />
            <InfoRow label="Via" value={device.via} mono />
            <InfoRow label="Link" value={device.link} />
          </div>
        </Card>

        {/* Identity */}
        <Card title="Identity" className="detail-card">
          <div className="info-list">
            <div className="info-row info-row--editable">
              <span className="info-row__label">Name</span>
              <span
                className="info-row__value info-row__value--highlight info-row__value--editable"
                contentEditable
                suppressContentEditableWarning
                onBlur={handleNameEdit}
                onKeyDown={handleNameKeyDown}
                spellCheck={false}
              >
                {device.name || '-'}
              </span>
            </div>
            <InfoRow label="Hostname" value={device.hostname} />
            <InfoRow label="Registered" value={device.registered ? 'Yes' : 'No'} />
          </div>
        </Card>

        {/* Access & Schedule */}
        <Card title="Access Control" className="detail-card">
          <div className="info-list">
            <InfoRow label="Access" value={device.access || 'Default'} />
            <InfoRow label="Schedule" value={device.schedule || 'None'} />
            <InfoRow 
              label="Policy" 
              value={policy ? policy.name : 'Default'} 
              highlight={!!policy}
            />
          </div>
        </Card>

        {/* Traffic Statistics */}
        <Card title="Traffic Statistics" className="detail-card">
          <div className="traffic-stats">
            <div className="traffic-stat traffic-stat--down">
              <span className="traffic-stat__icon">↓</span>
              <div className="traffic-stat__info">
                <span className="traffic-stat__label">Downloaded</span>
                <span className="traffic-stat__value">{formatBytes(device.rxbytes)}</span>
              </div>
            </div>
            <div className="traffic-stat traffic-stat--up">
              <span className="traffic-stat__icon">↑</span>
              <div className="traffic-stat__info">
                <span className="traffic-stat__label">Uploaded</span>
                <span className="traffic-stat__value">{formatBytes(device.txbytes)}</span>
              </div>
            </div>
          </div>
        </Card>

        {/* Connection Info */}
        <Card title="Connection Info" className="detail-card detail-card--wide">
          <div className="info-list">
            <InfoRow label="Status" value={device.active ? 'Online' : 'Offline'} highlight />
            <InfoRow label="Session Uptime" value={formatUptime(device.uptime)} />
            <InfoRow label="First Seen" value={formatDateTime(device.first_seen)} />
            <InfoRow label="Last Seen" value={formatDateTime(device.last_seen)} />
          </div>
        </Card>
      </div>
    </div>
  );
}

function InfoRow({ 
  label, 
  value, 
  mono = false,
  highlight = false 
}: { 
  label: string; 
  value: string | null; 
  mono?: boolean;
  highlight?: boolean;
}) {
  const valueClass = [
    'info-row__value',
    mono && 'info-row__value--mono',
    highlight && 'info-row__value--highlight',
  ].filter(Boolean).join(' ');

  return (
    <div className="info-row">
      <span className="info-row__label">{label}</span>
      <span className={valueClass}>{value || '-'}</span>
    </div>
  );
}

