import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useAddDnsRoute,
  useDeleteDnsRoute,
  useNetworkInterfaces,
} from '../hooks';
import './DnsRouteGroup.css';

export function DnsRouteGroup() {
  const { name } = useParams<{ name: string }>();
  const navigate = useNavigate();

  const { data: groupsData, isLoading: groupsLoading } = useDomainGroups();
  const { data: routesData, isLoading: routesLoading } = useDnsRoutes();
  const { data: interfacesData } = useNetworkInterfaces();

  const addRoute = useAddDnsRoute();
  const deleteRoute = useDeleteDnsRoute();

  const group = useMemo(
    () => groupsData?.domain_groups.find((g) => g.name === name),
    [groupsData, name],
  );

  const route = useMemo(
    () => routesData?.routes.find((r) => r.group === name),
    [routesData, name],
  );

  const [selectedInterface, setSelectedInterface] = useState('');
  const [saveError, setSaveError] = useState<string | null>(null);

  // Sync selectedInterface when route data arrives
  useEffect(() => {
    if (route?.interface) setSelectedInterface(route.interface);
  }, [route?.interface]);

  const interfaceNames = useMemo(() => {
    const map = new Map<string, string>();
    interfacesData?.interfaces.forEach((iface) => {
      if (iface.id) map.set(iface.id, iface.description || iface.id);
    });
    return map;
  }, [interfacesData]);

  const handleSaveRoute = async () => {
    if (!selectedInterface || !name) return;
    setSaveError(null);
    try {
      if (route) {
        await deleteRoute.mutateAsync(route.index);
      }
      await addRoute.mutateAsync({
        group: name,
        interface: selectedInterface,
        comment: route?.comment || '',
      });
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : 'Failed to save routing rule');
    }
  };

  const isLoading = groupsLoading || routesLoading;
  const isSaving = addRoute.isPending || deleteRoute.isPending;
  const currentIfaceName = route?.interface
    ? interfaceNames.get(route.interface) || route.interface
    : null;

  if (isLoading) {
    return (
      <div className="dns-group-detail-page">
        <div className="dns-group-not-found">Loading...</div>
      </div>
    );
  }

  if (!group) {
    return (
      <div className="dns-group-detail-page">
        <div className="dns-group-detail__back">
          <button className="dns-group-detail__back-btn" onClick={() => navigate('/dns-routes')}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <polyline points="15,18 9,12 15,6" />
            </svg>
            DNS Routes
          </button>
        </div>
        <div className="dns-group-not-found">Domain group not found.</div>
      </div>
    );
  }

  return (
    <div className="dns-group-detail-page">
      <div className="dns-group-detail__back">
        <button className="dns-group-detail__back-btn" onClick={() => navigate('/dns-routes')}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polyline points="15,18 9,12 15,6" />
          </svg>
          DNS Routes
        </button>
      </div>

      <Header
        title={group.name}
        subtitle={
          group.description && group.description !== group.name
            ? group.description
            : `${group.domains.length} domain${group.domains.length !== 1 ? 's' : ''}`
        }
      />

      {/* Domains */}
      <Card
        title="Domains"
        subtitle={`${group.domains.length} domain${group.domains.length !== 1 ? 's' : ''} configured`}
      >
        {group.domains.length === 0 ? (
          <p className="dns-group-no-ips">No domains configured.</p>
        ) : (
          <ul className="dns-group-domains-list">
            {group.domains.map((domain) => (
              <li key={domain} className="dns-group-domains-list__item">
                {domain}
              </li>
            ))}
          </ul>
        )}
      </Card>

      {/* Resolved IP Addresses */}
      <Card title="Resolved IP Addresses">
        <p className="dns-group-no-ips">
          No IP addresses resolved yet. The router populates these automatically as DNS queries are
          made for the configured domains.
        </p>
      </Card>

      {/* Routing Rule */}
      <Card
        title="Routing Rule"
        subtitle={
          route
            ? `Traffic is routed via ${currentIfaceName}`
            : 'No routing rule configured for this group'
        }
      >
        <div className="dns-group-routing">
          <div className="dns-group-routing__form">
            <span className="dns-group-routing__label">
              {route ? 'Change interface:' : 'Assign interface:'}
            </span>
            <select
              className="dns-group-routing__select"
              value={selectedInterface}
              onChange={(e) => { setSelectedInterface(e.target.value); setSaveError(null); }}
            >
              <option value="">Select interface...</option>
              {interfacesData?.interfaces.map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
            <button
              className="dns-group-routing__save-btn"
              onClick={handleSaveRoute}
              disabled={!selectedInterface || isSaving}
            >
              {isSaving ? 'Saving...' : route ? 'Update' : 'Add Route'}
            </button>
          </div>
          {saveError && <div className="dns-group-routing__error">{saveError}</div>}
        </div>
      </Card>
    </div>
  );
}
