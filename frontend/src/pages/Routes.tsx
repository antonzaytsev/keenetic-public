import { useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, type Column } from '../components/ui';
import { useRoutes, useArpTable } from '../hooks';
import type { Route, ArpEntry } from '../api';
import './Routes.css';

// Helper to convert mask to CIDR notation
function maskToCidr(mask: string | null): number | null {
  if (!mask) return null;
  const parts = mask.split('.');
  if (parts.length !== 4) return null;
  
  let cidr = 0;
  for (const part of parts) {
    const num = parseInt(part, 10);
    if (isNaN(num)) return null;
    cidr += (num >>> 0).toString(2).split('1').length - 1;
  }
  return cidr;
}

// Format destination with CIDR
function formatDestination(destination: string | null, mask: string | null): string {
  if (!destination) return '-';
  const cidr = maskToCidr(mask);
  if (cidr !== null) {
    return `${destination}/${cidr}`;
  }
  return destination;
}

// Icons
const icons = {
  check: (
    <svg className="route-auto__icon route-auto__icon--yes" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <polyline points="20,6 9,17 4,12" />
    </svg>
  ),
  x: (
    <svg className="route-auto__icon route-auto__icon--no" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  ),
  routes: (
    <svg className="routes-section__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="6" cy="6" r="3" />
      <circle cx="18" cy="18" r="3" />
      <path d="M6 9v6c0 3 3 3 6 3h3" />
    </svg>
  ),
  arp: (
    <svg className="routes-section__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <rect x="2" y="4" width="20" height="16" rx="2" />
      <path d="M6 8h.01" />
      <path d="M10 8h.01" />
      <path d="M14 8h.01" />
      <path d="M6 12h12" />
      <path d="M6 16h12" />
    </svg>
  ),
};

type TabType = 'routes' | 'arp';

function getTabFromHash(hash: string): TabType {
  const tab = hash.replace('#', '');
  if (tab === 'arp') return 'arp';
  return 'routes';
}

export function Routes() {
  const location = useLocation();
  const navigate = useNavigate();
  const activeTab = getTabFromHash(location.hash);
  const { data: routesData, isLoading: routesLoading } = useRoutes();
  const { data: arpData, isLoading: arpLoading } = useArpTable();

  // Set default hash on mount if none present
  useEffect(() => {
    if (!location.hash) {
      navigate('#routes', { replace: true });
    }
  }, [location.hash, navigate]);

  const handleTabChange = (tab: TabType) => {
    navigate(`#${tab}`);
  };

  const routeColumns: Column<Route>[] = [
    {
      key: 'destination',
      header: 'Destination IP or network',
      render: (route) => (
        <div className="route-destination">
          <span className="route-destination__network">
            {formatDestination(route.destination, route.mask)}
          </span>
        </div>
      ),
    },
    {
      key: 'gateway',
      header: 'Gateway IP',
      render: (route) => (
        <span className={`route-gateway ${!route.gateway ? 'route-gateway--none' : ''}`}>
          {route.gateway || 'Direct'}
        </span>
      ),
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (route) => (
        <span className="route-interface">{route.interface || '-'}</span>
      ),
    },
    {
      key: 'auto',
      header: 'Add automatically',
      width: '140px',
      render: (route) => (
        <span className="route-auto">
          {route.auto ? icons.check : icons.x}
          <span>{route.auto ? 'Yes' : 'No'}</span>
        </span>
      ),
    },
    {
      key: 'metric',
      header: 'Metric',
      width: '80px',
      align: 'right',
      render: (route) => (
        <span className="route-metric">{route.metric ?? '-'}</span>
      ),
    },
    {
      key: 'flags',
      header: 'Flags',
      width: '80px',
      render: (route) => (
        route.flags ? <span className="route-flags">{route.flags}</span> : <span>-</span>
      ),
    },
  ];

  const arpColumns: Column<ArpEntry>[] = [
    {
      key: 'ip',
      header: 'IP Address',
      render: (entry) => (
        <span className="mono-text">{entry.ip || '-'}</span>
      ),
    },
    {
      key: 'mac',
      header: 'MAC Address',
      render: (entry) => (
        <span className="mono-text mono-text--muted">{entry.mac || '-'}</span>
      ),
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (entry) => (
        <span className="route-interface">{entry.interface || '-'}</span>
      ),
    },
    {
      key: 'state',
      header: 'State',
      render: (entry) => {
        const state = entry.state?.toLowerCase() || 'unknown';
        return (
          <span className="arp-state">
            <span className={`arp-state__dot arp-state__dot--${state}`} />
            <span className="arp-state__text">{entry.state || 'Unknown'}</span>
          </span>
        );
      },
    },
  ];

  const autoRouteCount = routesData?.routes.filter(r => r.auto).length ?? 0;
  const manualRouteCount = (routesData?.count ?? 0) - autoRouteCount;

  return (
    <div className="routes-page">
      <Header
        title="Routing"
        subtitle={`${routesData?.count ?? 0} routes, ${arpData?.count ?? 0} ARP entries`}
      />

      {/* Stats Cards */}
      <div className="routes-stats">
        <Card className="routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-primary)' }}>
            {routesData?.count ?? 0}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            Total Routes
          </div>
        </Card>
        <Card className="routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-success)' }}>
            {autoRouteCount}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            Auto Routes
          </div>
        </Card>
        <Card className="routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-info)' }}>
            {manualRouteCount}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            Manual Routes
          </div>
        </Card>
        <Card className="routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-warning)' }}>
            {arpData?.count ?? 0}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            ARP Entries
          </div>
        </Card>
      </div>

      {/* Tabs and Content */}
      <div className="routes-tabbed">
        <div className="routes-tabs">
          <button
            className={`routes-tabs__tab ${activeTab === 'routes' ? 'routes-tabs__tab--active' : ''}`}
            onClick={() => handleTabChange('routes')}
          >
            {icons.routes}
            Static Routes
          </button>
          <button
            className={`routes-tabs__tab ${activeTab === 'arp' ? 'routes-tabs__tab--active' : ''}`}
            onClick={() => handleTabChange('arp')}
          >
            {icons.arp}
            ARP Table
          </button>
        </div>

        <div className="routes-tab-content">
          {/* Routes Table */}
          {activeTab === 'routes' && (
            <Table
              columns={routeColumns}
              data={routesData?.routes ?? []}
              keyExtractor={(route) => `${route.destination}-${route.mask}-${route.gateway}-${route.interface}`}
              loading={routesLoading}
              emptyMessage="No routes found"
            />
          )}

          {/* ARP Table */}
          {activeTab === 'arp' && (
            <Table
              columns={arpColumns}
              data={arpData?.arp_table ?? []}
              keyExtractor={(entry) => `${entry.ip}-${entry.mac}`}
              loading={arpLoading}
              emptyMessage="No ARP entries found"
            />
          )}
        </div>
      </div>
    </div>
  );
}

