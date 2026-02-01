import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, type Column, Modal } from '../components/ui';
import { useRoutes, useArpTable, useNetworkInterfaces, useCreateRoute, useDeleteRoute } from '../hooks';
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
  edit: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
    </svg>
  ),
  delete: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <polyline points="3,6 5,6 21,6" />
      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
    </svg>
  ),
  plus: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
};

type TabType = 'routes' | 'arp';

function getTabFromHash(hash: string): TabType {
  const tab = hash.replace('#', '');
  if (tab === 'arp') return 'arp';
  return 'routes';
}

// Helper to convert CIDR to mask
function cidrToMask(cidr: number): string {
  const mask = [];
  for (let i = 0; i < 4; i++) {
    const bits = Math.min(8, Math.max(0, cidr - i * 8));
    mask.push(256 - Math.pow(2, 8 - bits));
  }
  return mask.join('.');
}

// Parse destination/mask from CIDR notation
function parseDestination(value: string): { destination: string; mask: string } | null {
  const cidrMatch = value.match(/^(\d+\.\d+\.\d+\.\d+)\/(\d+)$/);
  if (cidrMatch) {
    return {
      destination: cidrMatch[1],
      mask: cidrToMask(parseInt(cidrMatch[2], 10)),
    };
  }
  // Plain IP without CIDR
  const ipMatch = value.match(/^(\d+\.\d+\.\d+\.\d+)$/);
  if (ipMatch) {
    return {
      destination: ipMatch[1],
      mask: '255.255.255.255',
    };
  }
  return null;
}

interface RouteFormData {
  destination: string;
  gateway: string;
  interfaceId: string;
  metric: string;
}

const emptyFormData: RouteFormData = {
  destination: '',
  gateway: '',
  interfaceId: '',
  metric: '',
};

export function Routes() {
  const location = useLocation();
  const navigate = useNavigate();
  const activeTab = getTabFromHash(location.hash);
  const { data: routesData, isLoading: routesLoading } = useRoutes();
  const { data: arpData, isLoading: arpLoading } = useArpTable();
  const { data: interfacesData } = useNetworkInterfaces();
  
  // Mutations
  const createRoute = useCreateRoute();
  const deleteRoute = useDeleteRoute();

  // Modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingRoute, setEditingRoute] = useState<Route | null>(null);
  const [formData, setFormData] = useState<RouteFormData>(emptyFormData);
  const [formError, setFormError] = useState<string | null>(null);

  // Create a lookup map for interface IDs to descriptions
  const interfaceNames = useMemo(() => {
    const map = new Map<string, string>();
    if (interfacesData?.interfaces) {
      for (const iface of interfacesData.interfaces) {
        if (iface.id) {
          // Use description if available, otherwise use the ID
          map.set(iface.id, iface.description || iface.id);
        }
      }
    }
    return map;
  }, [interfacesData]);

  // Set default hash on mount if none present
  useEffect(() => {
    if (!location.hash) {
      navigate('#routes', { replace: true });
    }
  }, [location.hash, navigate]);

  const handleTabChange = (tab: TabType) => {
    navigate(`#${tab}`);
  };

  const openCreateModal = () => {
    setFormData(emptyFormData);
    setFormError(null);
    setEditingRoute(null);
    setIsCreateModalOpen(true);
  };

  const openEditModal = (route: Route) => {
    setFormData({
      destination: formatDestination(route.destination, route.mask),
      gateway: route.gateway || '',
      interfaceId: route.interface || '',
      metric: route.metric?.toString() || '',
    });
    setFormError(null);
    setEditingRoute(route);
    setIsCreateModalOpen(true);
  };

  const handleDeleteRoute = async (route: Route) => {
    if (!route.destination || !route.mask) {
      console.error('Cannot delete route: missing destination or mask', route);
      return;
    }
    try {
      await deleteRoute.mutateAsync({
        destination: route.destination,
        mask: route.mask,
      });
    } catch (err) {
      console.error('Failed to delete route:', err);
    }
  };

  const closeCreateModal = () => {
    setIsCreateModalOpen(false);
    setEditingRoute(null);
    setFormData(emptyFormData);
    setFormError(null);
  };

  const handleFormChange = (field: keyof RouteFormData, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    setFormError(null);
  };

  const handleSubmit = async () => {
    const parsed = parseDestination(formData.destination);
    if (!parsed) {
      setFormError('Invalid destination format. Use IP/CIDR (e.g., 10.0.0.0/24)');
      return;
    }

    if (!formData.gateway && !formData.interfaceId) {
      setFormError('Either gateway or interface is required');
      return;
    }

    try {
      // If editing, delete the old route first
      if (editingRoute && editingRoute.destination && editingRoute.mask) {
        await deleteRoute.mutateAsync({
          destination: editingRoute.destination,
          mask: editingRoute.mask,
        });
      }

      await createRoute.mutateAsync({
        destination: parsed.destination,
        mask: parsed.mask,
        gateway: formData.gateway || undefined,
        interface: formData.interfaceId || undefined,
        metric: formData.metric ? parseInt(formData.metric, 10) : undefined,
      });

      closeCreateModal();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to save route');
    }
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
      render: (route) => {
        const interfaceName = route.interface 
          ? interfaceNames.get(route.interface) || route.interface 
          : '-';
        return <span className="route-interface">{interfaceName}</span>;
      },
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
    {
      key: 'comment',
      header: 'Description',
      render: (route) => (
        <span className="route-comment">{route.comment || '-'}</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      width: '80px',
      align: 'right',
      render: (route) => (
        <div className="route-actions">
          <button
            className="route-actions__btn route-actions__btn--edit"
            onClick={() => openEditModal(route)}
            title="Edit route"
          >
            {icons.edit}
          </button>
          <button
            className="route-actions__btn route-actions__btn--delete"
            onClick={() => handleDeleteRoute(route)}
            title="Delete route"
          >
            {icons.delete}
          </button>
        </div>
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
      render: (entry) => {
        const interfaceName = entry.interface 
          ? interfaceNames.get(entry.interface) || entry.interface 
          : '-';
        return <span className="route-interface">{interfaceName}</span>;
      },
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
          <div className="routes-tabs__spacer" />
          {activeTab === 'routes' && (
            <button className="routes-add-btn" onClick={openCreateModal}>
              {icons.plus}
              Create route
            </button>
          )}
        </div>

        <div className="routes-tab-content">
          {/* Routes Table */}
          {activeTab === 'routes' && (
            <Table
              columns={routeColumns}
              data={routesData?.routes ?? []}
              keyExtractor={(route, index) => `${index}-${route.destination}-${route.mask}`}
              loading={routesLoading}
              emptyMessage="No routes found"
            />
          )}

          {/* ARP Table */}
          {activeTab === 'arp' && (
            <Table
              columns={arpColumns}
              data={arpData?.arp_table ?? []}
              keyExtractor={(entry, index) => `${index}-${entry.ip}-${entry.mac}`}
              loading={arpLoading}
              emptyMessage="No ARP entries found"
            />
          )}
        </div>
      </div>

      {/* Create/Edit Route Modal */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={closeCreateModal}
        title={editingRoute ? 'Edit Route' : 'Create Route'}
        footer={
          <>
            <button className="modal-btn modal-btn--secondary" onClick={closeCreateModal}>
              Cancel
            </button>
            <button
              className="modal-btn modal-btn--primary"
              onClick={handleSubmit}
              disabled={createRoute.isPending || deleteRoute.isPending}
            >
              {createRoute.isPending || deleteRoute.isPending ? 'Saving...' : 'Save'}
            </button>
          </>
        }
      >
        <div className="modal-form">
          <div className="modal-form__group">
            <label className="modal-form__label">Destination (IP/CIDR)</label>
            <input
              className="modal-form__input"
              placeholder="e.g., 10.0.0.0/24 or 192.168.1.1/32"
              value={formData.destination}
              onChange={(e) => handleFormChange('destination', e.target.value)}
            />
          </div>
          <div className="modal-form__row">
            <div className="modal-form__group">
              <label className="modal-form__label">Gateway IP</label>
              <input
                className="modal-form__input"
                placeholder="e.g., 192.168.1.1"
                value={formData.gateway}
                onChange={(e) => handleFormChange('gateway', e.target.value)}
              />
            </div>
            <div className="modal-form__group">
              <label className="modal-form__label">Interface</label>
              <select
                className="modal-form__select"
                value={formData.interfaceId}
                onChange={(e) => handleFormChange('interfaceId', e.target.value)}
              >
                <option value="">Select interface...</option>
                {interfacesData?.interfaces.map((iface) => (
                  <option key={iface.id} value={iface.id}>
                    {iface.description || iface.id}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Metric (optional)</label>
            <input
              className="modal-form__input"
              type="number"
              placeholder="e.g., 100"
              value={formData.metric}
              onChange={(e) => handleFormChange('metric', e.target.value)}
            />
          </div>
          {formError && <div className="modal-form__error">{formError}</div>}
        </div>
      </Modal>

    </div>
  );
}

