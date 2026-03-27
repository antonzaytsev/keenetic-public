import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useAddDnsRoute,
  useCreateDomainGroup,
  useDeleteDnsRoute,
  useNetworkInterfaces,
} from '../hooks';
import './DnsRouteGroup.css';

export function DnsRouteGroup() {
  const { name } = useParams<{ name: string }>();
  const navigate = useNavigate();
  const addInputRef = useRef<HTMLInputElement>(null);

  const { data: groupsData, isLoading: groupsLoading } = useDomainGroups();
  const { data: routesData, isLoading: routesLoading } = useDnsRoutes();
  const { data: interfacesData } = useNetworkInterfaces();

  const addRoute = useAddDnsRoute();
  const deleteRoute = useDeleteDnsRoute();
  const saveGroup = useCreateDomainGroup();

  const group = useMemo(
    () => groupsData?.domain_groups.find((g) => g.name === name),
    [groupsData, name],
  );

  const route = useMemo(
    () => routesData?.routes.find((r) => r.group === name),
    [routesData, name],
  );

  // ── Domain editing state ─────────────────────────────────────────────────
  const [domains, setDomains] = useState<string[]>([]);
  const [addInput, setAddInput] = useState('');
  const [domainsError, setDomainsError] = useState<string | null>(null);

  // Sync local domain list when group data loads (not while saving)
  useEffect(() => {
    if (group && !saveGroup.isPending) {
      setDomains(group.domains);
    }
  }, [group?.name, group?.domains.join(',')]);  // eslint-disable-line react-hooks/exhaustive-deps

  const persistDomains = async (updated: string[]) => {
    if (!name || !group) return;
    setDomainsError(null);
    try {
      await saveGroup.mutateAsync({ name, description: group.description || name, domains: updated });
    } catch (err) {
      // Revert optimistic update on failure
      setDomains(group.domains);
      setDomainsError(err instanceof Error ? err.message : 'Failed to save');
    }
  };

  const handleRemoveDomain = (domain: string) => {
    const updated = domains.filter((d) => d !== domain);
    setDomains(updated);
    persistDomains(updated);
  };

  const handleAddDomain = () => {
    const value = addInput.trim().toLowerCase();
    if (!value) return;
    if (domains.includes(value)) {
      setDomainsError(`"${value}" is already in the list`);
      return;
    }
    const updated = [...domains, value];
    setDomains(updated);
    setAddInput('');
    setDomainsError(null);
    addInputRef.current?.focus();
    persistDomains(updated);
  };

  const handleAddKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') { e.preventDefault(); handleAddDomain(); }
    if (e.key === 'Escape') { setAddInput(''); setDomainsError(null); }
  };

  // ── Routing rule state ───────────────────────────────────────────────────
  const [selectedInterface, setSelectedInterface] = useState('');
  const [routeError, setRouteError] = useState<string | null>(null);

  useEffect(() => {
    if (route?.interface) setSelectedInterface(route.interface);
  }, [route?.interface]);

  const handleInterfaceChange = async (newInterface: string) => {
    if (!name) return;
    setSelectedInterface(newInterface);
    setRouteError(null);
    try {
      if (route) await deleteRoute.mutateAsync(route.index);
      if (newInterface) {
        await addRoute.mutateAsync({ group: name, interface: newInterface, comment: route?.comment || '' });
      }
    } catch (err) {
      setSelectedInterface(route?.interface || '');
      setRouteError(err instanceof Error ? err.message : 'Failed to save routing rule');
    }
  };

  const isLoading = groupsLoading || routesLoading;
  const isSavingRoute = addRoute.isPending || deleteRoute.isPending;

  const backBtn = (
    <button className="dns-group-detail__back-btn" onClick={() => navigate('/dns-routes')}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <polyline points="15,18 9,12 15,6" />
      </svg>
      DNS Routes
    </button>
  );

  if (isLoading) {
    return (
      <div className="dns-group-detail-page">
        <div className="dns-group-detail__back">{backBtn}</div>
        <div className="dns-group-not-found">Loading...</div>
      </div>
    );
  }

  if (!group) {
    return (
      <div className="dns-group-detail-page">
        <div className="dns-group-detail__back">{backBtn}</div>
        <div className="dns-group-not-found">Domain group not found.</div>
      </div>
    );
  }

  return (
    <div className="dns-group-detail-page">
      <div className="dns-group-detail__back">{backBtn}</div>

      <Header
        title={group.description || group.name}
        subtitle={`${domains.length} domain${domains.length !== 1 ? 's' : ''}`}
      />

      {/* Domains editor */}
      <Card
        title="Domains"
        action={
          saveGroup.isPending ? (
            <span className="dns-domains-saving">Saving…</span>
          ) : undefined
        }
      >
        <div className="dns-domains-editor">
          {/* Domain list */}
          {domains.length > 0 && (
            <ul className="dns-domains-list">
              {domains.map((domain) => (
                <li key={domain} className="dns-domains-list__item">
                  <span className="dns-domains-list__name">{domain}</span>
                  <button
                    className="dns-domains-list__remove"
                    onClick={() => handleRemoveDomain(domain)}
                    title={`Remove ${domain}`}
                    aria-label={`Remove ${domain}`}
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <line x1="18" y1="6" x2="6" y2="18" />
                      <line x1="6" y1="6" x2="18" y2="18" />
                    </svg>
                  </button>
                </li>
              ))}
            </ul>
          )}

          {/* Add domain input */}
          <div className="dns-domains-add">
            <input
              ref={addInputRef}
              className="dns-domains-add__input"
              placeholder="Add domain (e.g. example.com)"
              value={addInput}
              onChange={(e) => { setAddInput(e.target.value); setDomainsError(null); }}
              onKeyDown={handleAddKeyDown}
            />
            <button
              className="dns-domains-btn dns-domains-btn--primary"
              onClick={handleAddDomain}
              disabled={!addInput.trim()}
            >
              Add
            </button>
          </div>

          {domainsError && <p className="dns-domains-error">{domainsError}</p>}
        </div>
      </Card>

      {/* Resolved IP Addresses */}
      <Card title="Resolved IP Addresses">
        <p className="dns-group-no-ips">
          No IP addresses resolved yet. The router populates these automatically as DNS queries
          are made for the configured domains.
        </p>
      </Card>

      {/* Routing Rule */}
      <Card
        title="Routing Rule"
        action={isSavingRoute ? <span className="dns-domains-saving">Saving…</span> : undefined}
      >
        <div className="dns-group-routing">
          <div className="dns-group-routing__form">
            <span className="dns-group-routing__label">Interface:</span>
            <select
              className="dns-group-routing__select"
              value={selectedInterface}
              disabled={isSavingRoute}
              onChange={(e) => handleInterfaceChange(e.target.value)}
            >
              <option value="">No routing rule</option>
              {interfacesData?.interfaces.map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          {routeError && <div className="dns-group-routing__error">{routeError}</div>}
        </div>
      </Card>
    </div>
  );
}
