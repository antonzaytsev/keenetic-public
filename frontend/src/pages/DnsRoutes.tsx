import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, type Column, Modal } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useCreateDomainGroup,
  useDeleteDomainGroup,
  useAddDnsRoute,
  useDeleteDnsRoute,
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
  description: string;
  domainsText: string;
  interface: string;
}

const emptyGroupForm: GroupFormData = { name: '', description: '', domainsText: '', interface: '' };

export function DnsRoutes() {
  const navigate = useNavigate();

  const { data: groupsData, isLoading: groupsLoading } = useDomainGroups();
  const { data: routesData } = useDnsRoutes();
  const { data: interfacesData } = useNetworkInterfaces();

  const createGroup = useCreateDomainGroup();
  const deleteGroup = useDeleteDomainGroup();
  const addRoute = useAddDnsRoute();
  const deleteRoute = useDeleteDnsRoute();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<DomainGroup | null>(null);
  const [form, setForm] = useState<GroupFormData>(emptyGroupForm);
  const [formError, setFormError] = useState<string | null>(null);

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

  const openCreateModal = () => {
    setForm(emptyGroupForm);
    setFormError(null);
    setEditingGroup(null);
    setIsModalOpen(true);
  };

  const openEditModal = (group: DomainGroup) => {
    const existingRoute = groupRouteMap.get(group.name);
    setForm({
      name: group.name,
      description: group.description || '',
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
    const { name, description, domainsText, interface: iface } = form;
    const domains = domainsText.split('\n').map((d) => d.trim()).filter(Boolean);

    if (!name.trim()) { setFormError('Name is required'); return; }
    if (!description.trim()) { setFormError('Description is required'); return; }
    if (domains.length === 0) { setFormError('At least one domain is required'); return; }

    try {
      await createGroup.mutateAsync({ name: name.trim(), description: description.trim(), domains });

      // Handle routing rule
      const existingRoute = groupRouteMap.get(name.trim());
      if (iface) {
        // Create or update route: delete old first if interface changed
        if (existingRoute && existingRoute.interface !== iface) {
          await deleteRoute.mutateAsync(existingRoute.index);
        }
        if (!existingRoute || existingRoute.interface !== iface) {
          await addRoute.mutateAsync({ group: name.trim(), interface: iface });
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
      const route = groupRouteMap.get(group.name);
      if (route) await deleteRoute.mutateAsync(route.index);
      await deleteGroup.mutateAsync(group.name);
    } catch (err) {
      console.error('Failed to delete group:', err);
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

  const isSaving = createGroup.isPending || addRoute.isPending || deleteRoute.isPending;

  return (
    <div className="dns-routes-page">
      <Header
        title="DNS Routes"
        subtitle={`${groupsData?.count ?? 0} domain groups · ${routesData?.count ?? 0} routing rules`}
      />

      <section className="dns-routes-section">
        <div className="dns-routes-section__header">
          <h2 className="dns-routes-section__title">Domain Name Lists</h2>
          <button className="dns-routes-add-btn" onClick={openCreateModal}>
            {icons.plus}
            Create group
          </button>
        </div>
        <Card padding="none">
          <Table
            columns={columns}
            data={groupsData?.domain_groups ?? []}
            keyExtractor={(g) => g.name}
            loading={groupsLoading}
            emptyMessage="No domain groups configured"
            onRowClick={(g) => navigate(`/dns-routes/${encodeURIComponent(g.name)}`)}
          />
        </Card>
      </section>

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
            <label className="modal-form__label">Name (identifier)</label>
            <input
              className="modal-form__input"
              placeholder="e.g., youtube"
              value={form.name}
              disabled={!!editingGroup}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Description</label>
            <input
              className="modal-form__input"
              placeholder="e.g., YouTube"
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
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
              {interfacesData?.interfaces.map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          {formError && <div className="modal-form__error">{formError}</div>}
        </div>
      </Modal>
    </div>
  );
}
