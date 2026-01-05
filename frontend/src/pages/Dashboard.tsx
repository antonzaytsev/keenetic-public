import { Header } from '../components/layout';
import { Card, CircularProgress, Progress, StatusBadge } from '../components/ui';
import { useSystemResources, useSystemInfo, useDevices, useNetworkInterfaces } from '../hooks';
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

  const activeDevices = devices?.devices.filter((d) => d.active).length ?? 0;
  const totalDevices = devices?.count ?? 0;
  const wanInterface = interfaces?.interfaces.find((i) => i.defaultgw);

  return (
    <div className="dashboard">
      <Header 
        title="Dashboard" 
        subtitle={systemInfo?.info.model ? `${systemInfo.info.model} • ${systemInfo.info.firmware_version}` : undefined}
      />

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
            <StatusBadge active={true} />
          </div>
        </Card>

        <Card className="stat-card">
          <div className="stat-card__content">
            <div className="stat-card__value">{wanInterface?.address ?? 'N/A'}</div>
            <div className="stat-card__label">WAN IP</div>
          </div>
          <div className="stat-card__meta">
            <StatusBadge active={wanInterface?.connected ?? false} />
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

      {/* Recent devices */}
      <Card title="Recent Devices" className="recent-devices-card">
        <div className="recent-devices">
          {devices?.devices.slice(0, 5).map((device) => (
            <div key={device.mac} className="recent-device">
              <div className="recent-device__info">
                <span className="recent-device__name">{device.name || device.hostname || 'Unknown'}</span>
                <span className="recent-device__ip">{device.ip}</span>
              </div>
              <StatusBadge active={device.active} />
            </div>
          ))}
          {(!devices || devices.devices.length === 0) && (
            <div className="recent-devices__empty">No devices found</div>
          )}
        </div>
      </Card>
    </div>
  );
}

