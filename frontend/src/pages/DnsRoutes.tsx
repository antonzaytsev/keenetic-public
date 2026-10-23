import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, type Column, Modal } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useCreateDomainGroup,
  useDeleteDomainGroup,
  useAddDnsRoute,
  useDeleteDnsRoute,
  useBulkAddRoutes,
  useNetworkInterfaces,
} from '../hooks';
import type { DomainGroup, DnsRoute } from '../api';
import './DnsRoutes.css';

const icons = {
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

interface GroupFormData {
  name: string;
  domainsText: string;
  interface: string;
}

const emptyGroupForm: GroupFormData = { name: '', domainsText: '', interface: '' };

export function DnsRoutes() {
  const navigate = useNavigate();

  const { data: groupsData, isLoading: groupsLoading, isError: groupsError } = useDomainGroups();
  const { data: routesData, isLoading: routesLoading, isError: routesError } = useDnsRoutes();
  const { data: interfacesData, isLoading: interfacesLoading } = useNetworkInterfaces();

  const createGroup = useCreateDomainGroup();
  const deleteGroup = useDeleteDomainGroup();
  const addRoute = useAddDnsRoute();
  const deleteRoute = useDeleteDnsRoute();
  const bulkAddRoutes = useBulkAddRoutes();

  const [activeTab, setActiveTab] = useState<'groups' | 'domains'>('groups');
  const [domainSearch, setDomainSearch] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<DomainGroup | null>(null);
  const [form, setForm] = useState<GroupFormData>(emptyGroupForm);
  const [formError, setFormError] = useState<string | null>(null);

  // Bulk assign state
  const [isBulkModalOpen, setIsBulkModalOpen] = useState(false);
  const [bulkInterface, setBulkInterface] = useState('');
  const [bulkError, setBulkError] = useState<string | null>(null);

  // Map group name → its DNS route
  const groupRouteMap = useMemo(() => {
    const map = new Map<string, DnsRoute>();
    routesData?.routes.forEach((r) => { if (r.group) map.set(r.group, r); });
    return map;
  }, [routesData]);

  // Map interface id → display name
  const interfaceNames = useMemo(() => {
    const map = new Map<string, string>();
    interfacesData?.interfaces.forEach((iface) => {
      if (iface.id) map.set(iface.id, iface.description || iface.id);
    });
    return map;
  }, [interfacesData]);

  const domainRows = useMemo(() => (
    (groupsData?.domain_groups ?? []).flatMap((group) => (
      group.domains.map((domain, index) => ({
        key: JSON.stringify([group.name, domain, index]),
        domain,
        group,
        interface: groupRouteMap.get(group.name)?.interface,
      }))
    )).sort((a, b) => (
      a.domain.localeCompare(b.domain, undefined, { sensitivity: 'base' })
      || (a.group.description || a.group.name).localeCompare(b.group.description || b.group.name)
    ))
  ), [groupsData, groupRouteMap]);

  const filteredDomains = useMemo(() => {
    const query = domainSearch.trim().toLowerCase();
    return domainRows.filter((row) => row.domain.toLowerCase().includes(query));
  }, [domainRows, domainSearch]);

  const domainColumns: Column<(typeof domainRows)[number]>[] = [
    {
      key: 'domain',
      header: 'Domain',
      render: (row) => <span className="dns-domain-name">{row.domain}</span>,
    },
    {
      key: 'group',
      header: 'Group',
      render: (row) => (
        <Link className="dns-group-link" to={`/dns-routes/${encodeURIComponent(row.group.name)}`}>
          {row.group.description || row.group.name}
        </Link>
      ),
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (row) => row.interface ? (
        <span className="dns-route-interface">
          {interfaceNames.get(row.interface) || row.interface}
        </span>
      ) : <span className="dns-no-route">No routing rule</span>,
    },
  ];

  const openCreateModal = () => {
    setForm(emptyGroupForm);
    setFormError(null);
    setEditingGroup(null);
    setIsModalOpen(true);
  };

  const openEditModal = (group: DomainGroup) => {
    const existingRoute = groupRouteMap.get(group.name);
    setForm({
      name: group.description || group.name,
      domainsText: group.domains.join('\n'),
      interface: existingRoute?.interface || '',
    });
    setFormError(null);
    setEditingGroup(group);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingGroup(null);
    setForm(emptyGroupForm);
    setFormError(null);
  };

  const handleSubmit = async () => {
    const { name, domainsText, interface: iface } = form;
    const domains = domainsText.split('\n').map((d) => d.trim()).filter(Boolean);

    if (!name.trim()) { setFormError('Name is required'); return; }
    if (domains.length === 0) { setFormError('At least one domain is required'); return; }

    // Use name as both the identifier key and human-readable description
    const groupName = editingGroup ? editingGroup.name : name.trim();
    const groupDesc = name.trim();

    try {
      await createGroup.mutateAsync({ name: groupName, description: groupDesc, domains });

      // Handle routing rule
      const existingRoute = groupRouteMap.get(groupName);
      if (iface) {
        if (!existingRoute || existingRoute.interface !== iface) {
          await addRoute.mutateAsync({
            group: groupName,
            interface: iface,
          });
        }
      } else if (existingRoute) {
        // Interface cleared — remove the route
        await deleteRoute.mutateAsync(existingRoute.index);
      }

      closeModal();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to save');
    }
  };

  const handleDelete = async (group: DomainGroup) => {
    try {
      // Backend handles route cleanup + restores surviving routes after firmware cascade
      await deleteGroup.mutateAsync(group.name);
    } catch (err) {
      console.error('Failed to delete group:', err);
    }
  };

  // Groups that have no interface assigned
  const groupsWithoutRoute = useMemo(() => {
    return (groupsData?.domain_groups ?? []).filter((g) => !groupRouteMap.has(g.name));
  }, [groupsData, groupRouteMap]);

  const handleBulkAssign = async () => {
    if (!bulkInterface) { setBulkError('Please select an interface'); return; }

    const routes = groupsWithoutRoute.map((g) => ({
      group: g.name,
      interface: bulkInterface,
    }));

    if (routes.length === 0) { setBulkError('No groups without interface'); return; }

    try {
      await bulkAddRoutes.mutateAsync(routes);
      setIsBulkModalOpen(false);
      setBulkInterface('');
      setBulkError(null);
    } catch (err) {
      setBulkError(err instanceof Error ? err.message : 'Failed to assign');
    }
  };

  const columns: Column<DomainGroup>[] = [
    {
      key: 'name',
      header: 'Name',
      render: (group) => (
        <span className="dns-group-name-cell">{group.description || group.name}</span>
      ),
    },
    {
      key: 'domains',
      header: 'Domain Names',
      width: '140px',
      align: 'right',
      render: (group) => <span className="dns-count">{group.domains.length}</span>,
    },
    {
      key: 'ipv4',
      header: 'IPv4 Addresses',
      width: '145px',
      align: 'right',
      render: () => <span className="dns-count">0</span>,
    },
    {
      key: 'ipv6',
      header: 'IPv6 Addresses',
      width: '145px',
      align: 'right',
      render: () => <span className="dns-count">0</span>,
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (group) => {
        const route = groupRouteMap.get(group.name);
        if (!route?.interface) return <span className="dns-no-route">—</span>;
        return (
          <span className="dns-route-interface">
            {interfaceNames.get(route.interface) || route.interface}
          </span>
        );
      },
    },
    {
      key: 'auto',
      header: 'Add Automatically',
      width: '160px',
      render: (group) => {
        const route = groupRouteMap.get(group.name);
        if (!route) return <span className="dns-no-route">—</span>;
        return (
          <span className={`dns-bool ${route.auto ? 'dns-bool--yes' : 'dns-bool--no'}`}>
            {route.auto ? 'Yes' : 'No'}
          </span>
        );
      },
    },
    {
      key: 'actions',
      header: '',
      width: '80px',
      align: 'right',
      render: (group) => (
        <div className="dns-actions">
          <button
            className="dns-actions__btn dns-actions__btn--edit"
            onClick={(e) => { e.stopPropagation(); openEditModal(group); }}
            title="Edit group"
          >
            {icons.edit}
          </button>
          <button
            className="dns-actions__btn dns-actions__btn--delete"
            onClick={(e) => { e.stopPropagation(); handleDelete(group); }}
            title="Delete group"
          >
            {icons.delete}
          </button>
        </div>
      ),
    },
  ];

  const isSaving = createGroup.isPending || addRoute.isPending || deleteRoute.isPending || bulkAddRoutes.isPending;

  return (
    <div className="dns-routes-page">
      <Header
        title="DNS Routes"
        subtitle={`${groupsData?.count ?? 0} domain groups · ${routesData?.count ?? 0} routing rules`}
      />

      <div className="dns-routes-tabs" role="tablist" aria-label="DNS routes view">
        {(['groups', 'domains'] as const).map((tab) => (
          <button
            key={tab}
            id={`dns-${tab}-tab`}
            role="tab"
            aria-selected={activeTab === tab}
            aria-controls={`dns-${tab}-panel`}
            tabIndex={activeTab === tab ? 0 : -1}
            className={`dns-routes-tabs__tab ${activeTab === tab ? 'dns-routes-tabs__tab--active' : ''}`}
            onClick={() => setActiveTab(tab)}
            onKeyDown={(event) => {
              if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
                event.preventDefault();
                const next = event.key === 'Home' ? 'groups' : event.key === 'End' ? 'domains'
                  : tab === 'groups' ? 'domains' : 'groups';
                setActiveTab(next);
                document.getElementById(`dns-${next}-tab`)?.focus();
              }
            }}
          >
            {tab === 'groups' ? 'Groups' : 'Domains'}
          </button>
        ))}
      </div>

      {activeTab === 'groups' ? (
      <section className="dns-routes-section" id="dns-groups-panel" role="tabpanel" aria-labelledby="dns-groups-tab">
        <div className="dns-routes-section__header">
          <h2 className="dns-routes-section__title">Domain Name Lists</h2>
          <div className="dns-routes-section__actions">
            {groupsWithoutRoute.length > 0 && (
              <button
                className="dns-routes-add-btn dns-routes-add-btn--secondary"
                onClick={() => { setBulkInterface(''); setBulkError(null); setIsBulkModalOpen(true); }}
              >
                Assign interface to {groupsWithoutRoute.length} unrouted
              </button>
            )}
            <button className="dns-routes-add-btn" onClick={openCreateModal}>
              {icons.plus}
              Create group
            </button>
          </div>
        </div>
        <Card padding="none">
          <Table
            columns={columns}
            data={[...(groupsData?.domain_groups ?? [])].sort((a, b) =>
              (a.description || a.name).localeCompare(b.description || b.name)
            )}
            keyExtractor={(g) => g.name}
            loading={groupsLoading}
            emptyMessage="No domain groups configured"
            onRowClick={(g) => navigate(`/dns-routes/${encodeURIComponent(g.name)}`)}
          />
        </Card>
      </section>
      ) : (
        <section className="dns-routes-section" id="dns-domains-panel" role="tabpanel" aria-labelledby="dns-domains-tab">
          <div className="dns-routes-section__header">
            <h2 className="dns-routes-section__title">All Domains</h2>
            <label className="dns-domain-search">
              <span>Search by domain name</span>
              <input
                type="search"
                className="modal-form__input"
                placeholder="e.g. youtube.com"
                value={domainSearch}
                onChange={(event) => setDomainSearch(event.target.value)}
              />
            </label>
          </div>
          {groupsError || routesError ? (
            <p className="modal-form__error" role="alert">Unable to load domains or routing rules. Retrying…</p>
          ) : (
            <>
              {!groupsLoading && !routesLoading && (
                <span className="dns-no-route" role="status">
                  {filteredDomains.length} of {domainRows.length} domain entries
                </span>
              )}
              <Card padding="none">
                <Table
                  columns={domainColumns}
                  data={filteredDomains}
                  keyExtractor={(row) => row.key}
                  loading={groupsLoading || routesLoading || interfacesLoading}
                  emptyMessage={domainSearch.trim() ? 'No domains match your search' : 'No domains configured'}
                />
              </Card>
            </>
          )}
        </section>
      )}

      {/* Create / Edit Group Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={closeModal}
        title={editingGroup ? 'Edit Domain Group' : 'Create Domain Group'}
        footer={
          <>
            <button className="modal-btn modal-btn--secondary" onClick={closeModal}>
              Cancel
            </button>
            <button
              className="modal-btn modal-btn--primary"
              onClick={handleSubmit}
              disabled={isSaving}
            >
              {isSaving ? 'Saving…' : 'Save'}
            </button>
          </>
        }
      >
        <div className="modal-form">
          <div className="modal-form__group">
            <label className="modal-form__label">Name</label>
            <input
              className="modal-form__input"
              placeholder="e.g., youtube"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Domains</label>
            <textarea
              className="modal-form__textarea"
              placeholder={'youtube.com\ngooglevideo.com\nytimg.com'}
              value={form.domainsText}
              onChange={(e) => setForm((f) => ({ ...f, domainsText: e.target.value }))}
            />
            <div className="modal-form__hint">One domain per line</div>
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Route via interface (optional)</label>
            <select
              className="modal-form__select"
              value={form.interface}
              onChange={(e) => setForm((f) => ({ ...f, interface: e.target.value }))}
            >
              <option value="">No routing rule</option>
              {[...(interfacesData?.interfaces ?? [])]
                .filter((iface) => iface.security === 'public' && iface.connected)
                .sort((a, b) => (a.description || a.id).localeCompare(b.description || b.id))
                .map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          {formError && <div className="modal-form__error">{formError}</div>}
        </div>
      </Modal>

      {/* Bulk Assign Interface Modal */}
      <Modal
        isOpen={isBulkModalOpen}
        onClose={() => setIsBulkModalOpen(false)}
        title={`Assign interface to ${groupsWithoutRoute.length} groups`}
        footer={
          <>
            <button className="modal-btn modal-btn--secondary" onClick={() => setIsBulkModalOpen(false)}>
              Cancel
            </button>
            <button
              className="modal-btn modal-btn--primary"
              onClick={handleBulkAssign}
              disabled={bulkAddRoutes.isPending}
            >
              {bulkAddRoutes.isPending ? 'Assigning…' : 'Assign'}
            </button>
          </>
        }
      >
        <div className="modal-form">
          <div className="modal-form__group">
            <label className="modal-form__label">Interface for all unrouted groups</label>
            <select
              className="modal-form__select"
              value={bulkInterface}
              onChange={(e) => setBulkInterface(e.target.value)}
            >
              <option value="">Select interface</option>
              {[...(interfacesData?.interfaces ?? [])]
                .filter((iface) => iface.security === 'public' && iface.connected)
                .sort((a, b) => (a.description || a.id).localeCompare(b.description || b.id))
                .map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Groups to update</label>
            <ul className="dns-bulk-group-list">
              {groupsWithoutRoute
                .sort((a, b) => (a.description || a.name).localeCompare(b.description || b.name))
                .map((g) => (
                <li key={g.name} className="dns-bulk-group-list__item">
                  {g.description || g.name}
                </li>
              ))}
            </ul>
          </div>
          {bulkError && <div className="modal-form__error">{bulkError}</div>}
        </div>
      </Modal>
    </div>
  );
}
