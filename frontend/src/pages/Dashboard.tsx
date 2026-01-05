import { Header } from '../components/layout';
import { Card, CircularProgress, Progress } from '../components/ui';
import { useSystemResources, useSystemInfo, useDevices, useNetworkInterfaces, useInternetStatus } from '../hooks';
import './Dashboard.css';

function formatUptime(seconds: number | null): string {
  if (!seconds) return 'N/A';
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  
  if (days > 0) return `${days}d ${hours}h ${mins}m`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

function formatBytes(bytes: number | null): string {
  if (bytes === null) return 'N/A';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let value = bytes;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(1)} ${units[i]}`;
}

export function Dashboard() {
  const { data: resources, isLoading: resourcesLoading } = useSystemResources();
  const { data: systemInfo } = useSystemInfo();
  const { data: devices } = useDevices();
  const { data: interfaces } = useNetworkInterfaces();
  const { data: internetStatus } = useInternetStatus();

  const activeDevices = devices?.devices.filter((d) => d.active).length ?? 0;
  const totalDevices = devices?.count ?? 0;
  const wanInterface = interfaces?.interfaces.find((i) => i.defaultgw);
  const isOnline = internetStatus?.status.connected ?? false;

  return (
    <div className="dashboard">
      <Header 
        title="Dashboard" 
        subtitle={systemInfo?.info.model ? `${systemInfo.info.model} • ${systemInfo.info.firmware_version}` : undefined}
      />

      {/* Connection Status Banner */}
      <div className={`connection-banner ${isOnline ? 'connection-banner--online' : 'connection-banner--offline'}`}>
        <div className="connection-banner__indicator" />
        <div className="connection-banner__content">
          <span className="connection-banner__status">{isOnline ? 'Online' : 'Offline'}</span>
          <span className="connection-banner__detail">
            {isOnline 
              ? `Connected via ${wanInterface?.address ?? 'WAN'}` 
              : 'No internet connection'}
          </span>
        </div>
        {isOnline && wanInterface?.gateway && (
          <div className="connection-banner__meta">
            <span>Gateway: {wanInterface.gateway}</span>
          </div>
        )}
      </div>

      {/* Stats row */}
      <div className="dashboard__stats">
        <Card className="stat-card">
          <div className="stat-card__content">
            <div className="stat-card__value">{activeDevices}</div>
            <div className="stat-card__label">Active Devices</div>
          </div>
          <div className="stat-card__meta">
            <span className="stat-card__total">{totalDevices} total</span>
          </div>
        </Card>

        <Card className="stat-card">
          <div className="stat-card__content">
            <div className="stat-card__value">{formatUptime(resources?.resources.uptime ?? null)}</div>
            <div className="stat-card__label">Uptime</div>
          </div>
          <div className="stat-card__meta">
            <span className="stat-card__detail">Since boot</span>
          </div>
        </Card>

        <Card className="stat-card">
          <div className="stat-card__content">
            <div className="stat-card__value">{wanInterface?.address ?? 'N/A'}</div>
            <div className="stat-card__label">WAN IP</div>
          </div>
          <div className="stat-card__meta">
            <span className="stat-card__detail">{wanInterface?.id ?? 'WAN'}</span>
          </div>
        </Card>

        <Card className="stat-card">
          <div className="stat-card__content">
            <div className="stat-card__value">{interfaces?.count ?? 0}</div>
            <div className="stat-card__label">Interfaces</div>
          </div>
          <div className="stat-card__meta">
            <span className="stat-card__detail">Active</span>
          </div>
        </Card>
      </div>

      {/* Resource gauges */}
      <div className="dashboard__resources">
        <Card title="System Resources" className="resources-card">
          {resourcesLoading ? (
            <div className="resources-card__loading">Loading...</div>
          ) : (
            <div className="resources-card__gauges">
              <div className="gauge-item">
                <CircularProgress
                  value={resources?.resources.cpu?.load_percent ?? 0}
                  label="CPU"
                  size={140}
                  strokeWidth={10}
                />
              </div>
              <div className="gauge-item">
                <CircularProgress
                  value={resources?.resources.memory?.used_percent ?? 0}
                  label="Memory"
                  size={140}
                  strokeWidth={10}
                />
              </div>
              {resources?.resources.swap && resources.resources.swap.total > 0 && (
                <div className="gauge-item">
                  <CircularProgress
                    value={resources.resources.swap.used_percent}
                    label="Swap"
                    size={140}
                    strokeWidth={10}
                  />
                </div>
              )}
            </div>
          )}
        </Card>

        <Card title="Memory Details" className="memory-card">
          {resources?.resources.memory && (
            <div className="memory-details">
              <div className="memory-row">
                <span className="memory-row__label">Total</span>
                <span className="memory-row__value">{formatBytes(resources.resources.memory.total)}</span>
              </div>
              <div className="memory-row">
                <span className="memory-row__label">Used</span>
                <span className="memory-row__value">{formatBytes(resources.resources.memory.used)}</span>
              </div>
              <div className="memory-row">
                <span className="memory-row__label">Free</span>
                <span className="memory-row__value">{formatBytes(resources.resources.memory.free)}</span>
              </div>
              <div className="memory-row">
                <span className="memory-row__label">Buffers</span>
                <span className="memory-row__value">{formatBytes(resources.resources.memory.buffers)}</span>
              </div>
              <div className="memory-row">
                <span className="memory-row__label">Cached</span>
                <span className="memory-row__value">{formatBytes(resources.resources.memory.cached)}</span>
              </div>
              <div className="memory-bar">
                <Progress
                  value={resources.resources.memory.used_percent}
                  label="Usage"
                  size="lg"
                />
              </div>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}

