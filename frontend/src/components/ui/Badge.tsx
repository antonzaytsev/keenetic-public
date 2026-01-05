import './Badge.css';

type BadgeVariant = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

interface BadgeProps {
  children: React.ReactNode;
  variant?: BadgeVariant;
  dot?: boolean;
  size?: 'sm' | 'md';
}

export function Badge({ children, variant = 'neutral', dot = false, size = 'md' }: BadgeProps) {
  return (
    <span className={`badge badge--${variant} badge--${size}`}>
      {dot && <span className="badge__dot" />}
      {children}
    </span>
  );
}

// Convenience components for common statuses
export function StatusBadge({ active }: { active: boolean }) {
  return (
    <Badge variant={active ? 'success' : 'neutral'} dot size="sm">
      {active ? 'Online' : 'Offline'}
    </Badge>
  );
}

export function ConnectionBadge({ connected }: { connected: boolean | null }) {
  if (connected === null) return <Badge variant="neutral" size="sm">Unknown</Badge>;
  return (
    <Badge variant={connected ? 'success' : 'danger'} dot size="sm">
      {connected ? 'Connected' : 'Disconnected'}
    </Badge>
  );
}

