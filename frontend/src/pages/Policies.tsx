import { Header } from '../components/layout';
import { Card, Table, Badge, type Column } from '../components/ui';
import { usePolicies } from '../hooks';
import type { Policy } from '../api';
import './Policies.css';

export function Policies() {
  const { data, isLoading, error } = usePolicies();

  const columns: Column<Policy>[] = [
    {
      key: 'name',
      header: 'Policy Name',
      render: (policy) => (
        <div className="policy-name">
          <span className="policy-name__value">{policy.name}</span>
          <span className="policy-name__id">{policy.id}</span>
        </div>
      ),
    },
    {
      key: 'interfaces',
      header: 'Active Interfaces',
      render: (policy) => (
        <div className="policy-interfaces">
          {policy.interfaces.length > 0 ? (
            policy.interfaces.map((iface) => (
              <Badge key={iface} variant="info" size="sm">
                {iface}
              </Badge>
            ))
          ) : (
            <span className="policy-interfaces__empty">No interfaces</span>
          )}
        </div>
      ),
    },
    {
      key: 'interface_count',
      header: 'Interface Count',
      align: 'center',
      width: '140px',
      render: (policy) => (
        <span className="policy-count">{policy.interface_count}</span>
      ),
    },
    {
      key: 'devices',
      header: 'Assigned Devices',
      align: 'center',
      width: '140px',
      render: (policy) => {
        const deviceCount = data?.device_assignments
          ? Object.values(data.device_assignments).filter((p) => p === policy.id).length
          : 0;
        return (
          <span className={`policy-devices ${deviceCount > 0 ? 'policy-devices--active' : ''}`}>
            {deviceCount}
          </span>
        );
      },
    },
  ];

  return (
    <div className="policies-page">
      <Header
        title="Routing Policies"
        subtitle={`${data?.count ?? 0} policies configured`}
      />

      <Card padding="none" className="policies-table-card">
        {error ? (
          <div className="policies-error">
            <p>Failed to load policies</p>
            <span>{error.message}</span>
          </div>
        ) : (
          <Table
            columns={columns}
            data={data?.policies ?? []}
            keyExtractor={(policy) => policy.id}
            loading={isLoading}
            emptyMessage="No routing policies configured"
          />
        )}
      </Card>

    </div>
  );
}

