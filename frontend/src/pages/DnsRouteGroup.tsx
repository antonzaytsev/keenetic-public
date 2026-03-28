import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Card } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useAddDnsRoute,
  useCreateDomainGroup,
  useDeleteDomainGroup,
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
  const [textareaMode, setTextareaMode] = useState(false);
  const [textareaValue, setTextareaValue] = useState('');

  // Sync local domain list when group data loads (not while saving)
  useEffect(() => {
    if (group && !saveGroup.isPending) {
      setDomains(group.domains);
    }
  }, [group?.name, group?.domains.join(',')]);  // eslint-disable-line react-hooks/exhaustive-deps

  const enterTextareaMode = () => {
    setTextareaValue(domains.join('\n'));
    setDomainsError(null);
    setTextareaMode(true);
  };

  const exitTextareaMode = async () => {
    const updated = textareaValue
      .split('\n')
      .map((d) => d.trim().toLowerCase())
      .filter(Boolean)
      .filter((d, i, arr) => arr.indexOf(d) === i); // deduplicate
    setDomains(updated);
    setTextareaMode(false);
    await persistDomains(updated);
  };

  const cancelTextareaMode = () => {
    setTextareaMode(false);
    setDomainsError(null);
  };

  const persistDomains = async (updated: string[]) => {
    if (!name || !group) return;
    setDomainsError(null);
    try {
      await saveGroup.mutateAsync({ name, description: group.description || name, domains: updated });
    } catch (err) {
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

  // ── Group name editing ───────────────────────────────────────────────────
  const [nameValue, setNameValue] = useState('');
  const [nameError, setNameError] = useState<string | null>(null);
  const renameGroup = useCreateDomainGroup();
  const removeGroup = useDeleteDomainGroup();

  useEffect(() => {
    if (group) setNameValue(group.description || group.name);
  }, [group?.name, group?.description]);  // eslint-disable-line react-hooks/exhaustive-deps

  const handleNameBlur = async () => {
    const newName = nameValue.trim();
    if (!newName || !group || !name) return;
    if (newName === (group.description || group.name)) return; // unchanged
    setNameError(null);
    try {
      // Create new group with new name, delete old one
      await renameGroup.mutateAsync({ name: newName, description: newName, domains: group.domains });
      if (route) {
        await deleteRoute.mutateAsync(route.index);
        await addRoute.mutateAsync({ group: newName, interface: route.interface || '', comment: route.comment || '' });
      }
      await removeGroup.mutateAsync(name);
      navigate(`/dns-routes/${encodeURIComponent(newName)}`, { replace: true });
    } catch (err) {
      setNameValue(group.description || group.name);
      setNameError(err instanceof Error ? err.message : 'Failed to rename');
    }
  };

  // ── Routing rule state ───────────────────────────────────────────────────
  const [selectedInterface, setSelectedInterface] = useState('');
  const [routeAuto, setRouteAuto] = useState(true);
  const [routeExclusive, setRouteExclusive] = useState(false);
  const [routeError, setRouteError] = useState<string | null>(null);

  useEffect(() => {
    if (route) {
      setSelectedInterface(route.interface || '');
      setRouteAuto(route.auto ?? true);
      setRouteExclusive(route.exclusive ?? false);
    }
  }, [route?.interface, route?.auto, route?.exclusive]);  // eslint-disable-line react-hooks/exhaustive-deps

  const persistRoute = async (iface: string, auto: boolean, exclusive: boolean) => {
    if (!name) return;
    setRouteError(null);
    try {
      if (route) await deleteRoute.mutateAsync(route.index);
      if (iface) {
        await addRoute.mutateAsync({ group: name, interface: iface, comment: route?.comment || '', auto, exclusive });
      }
    } catch (err) {
      if (route) {
        setSelectedInterface(route.interface || '');
        setRouteAuto(route.auto ?? true);
        setRouteExclusive(route.exclusive ?? false);
      }
      setRouteError(err instanceof Error ? err.message : 'Failed to save routing rule');
    }
  };

  const handleInterfaceChange = (newInterface: string) => {
    setSelectedInterface(newInterface);
    persistRoute(newInterface, routeAuto, routeExclusive);
  };

  const handleAutoChange = (checked: boolean) => {
    setRouteAuto(checked);
    if (selectedInterface) persistRoute(selectedInterface, checked, routeExclusive);
  };

  const handleExclusiveChange = (checked: boolean) => {
    setRouteExclusive(checked);
    if (selectedInterface) persistRoute(selectedInterface, routeAuto, checked);
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

  const domainsCardAction = saveGroup.isPending ? (
    <span className="dns-domains-saving">Saving…</span>
  ) : textareaMode ? (
    <div className="dns-domains-actions">
      <button className="dns-domains-btn dns-domains-btn--ghost" onClick={cancelTextareaMode}>
        Cancel
      </button>
      <button className="dns-domains-btn dns-domains-btn--primary" onClick={exitTextareaMode}>
        Apply
      </button>
    </div>
  ) : (
    <button className="dns-domains-btn dns-domains-btn--ghost" onClick={enterTextareaMode}>
      Edit as text
    </button>
  );

  return (
    <div className="dns-group-detail-page">
      <div className="dns-group-detail__back">{backBtn}</div>

      <div className="dns-group-header">
        <input
          className="dns-group-title-input"
          value={nameValue}
          onChange={(e) => { setNameValue(e.target.value); setNameError(null); }}
          onBlur={handleNameBlur}
          onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur(); if (e.key === 'Escape') { setNameValue(group.description || group.name); e.currentTarget.blur(); } }}
          aria-label="Group name"
        />
        <div className="dns-group-subtitle">
          {domains.length} domain{domains.length !== 1 ? 's' : ''}
        </div>
        {nameError && <p className="dns-domains-error">{nameError}</p>}
      </div>

      {/* Domains editor */}
      <Card title="Domains" action={domainsCardAction}>
        <div className="dns-domains-editor">
          {textareaMode ? (
            <>
              <textarea
                className="dns-domains-textarea"
                value={textareaValue}
                onChange={(e) => setTextareaValue(e.target.value)}
                placeholder={'youtube.com\ngooglevideo.com\nytimg.com'}
                autoFocus
              />
              <div className="dns-domains-textarea-hint">One domain per line. Duplicates removed on apply.</div>
            </>
          ) : (
            <>
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
            </>
          )}
          {domainsError && <p className="dns-domains-error">{domainsError}</p>}
        </div>
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
              {interfacesData?.interfaces.filter((iface) => iface.security === 'public').map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          {selectedInterface && (
            <div className="dns-group-routing__checkboxes">
              <label className="dns-group-routing__checkbox-label">
                <input
                  type="checkbox"
                  className="dns-group-routing__checkbox"
                  checked={routeAuto}
                  disabled={isSavingRoute}
                  onChange={(e) => handleAutoChange(e.target.checked)}
                />
                Add automatically
              </label>
              <label className="dns-group-routing__checkbox-label">
                <input
                  type="checkbox"
                  className="dns-group-routing__checkbox"
                  checked={routeExclusive}
                  disabled={isSavingRoute}
                  onChange={(e) => handleExclusiveChange(e.target.checked)}
                />
                Exclusive route
              </label>
            </div>
          )}
          {routeError && <div className="dns-group-routing__error">{routeError}</div>}
        </div>
      </Card>
    </div>
  );
}
