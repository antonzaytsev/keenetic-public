import './Progress.css';

interface ProgressProps {
  value: number;
  max?: number;
  label?: string;
  showValue?: boolean;
  variant?: 'default' | 'success' | 'warning' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}

function getVariant(value: number): 'success' | 'warning' | 'danger' {
  if (value < 60) return 'success';
  if (value < 85) return 'warning';
  return 'danger';
}

export function Progress({
  value,
  max = 100,
  label,
  showValue = true,
  variant = 'default',
  size = 'md',
}: ProgressProps) {
  const percentage = Math.min(100, Math.max(0, (value / max) * 100));
  const actualVariant = variant === 'default' ? getVariant(percentage) : variant;

  return (
    <div className={`progress progress--${size}`}>
      {(label || showValue) && (
        <div className="progress__header">
          {label && <span className="progress__label">{label}</span>}
          {showValue && (
            <span className={`progress__value progress__value--${actualVariant}`}>
              {percentage.toFixed(1)}%
            </span>
          )}
        </div>
      )}
      <div className="progress__track">
        <div
          className={`progress__fill progress__fill--${actualVariant}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
}

interface CircularProgressProps {
  value: number;
  max?: number;
  size?: number;
  strokeWidth?: number;
  label?: string;
  variant?: 'default' | 'success' | 'warning' | 'danger';
}

export function CircularProgress({
  value,
  max = 100,
  size = 120,
  strokeWidth = 8,
  label,
  variant = 'default',
}: CircularProgressProps) {
  const percentage = Math.min(100, Math.max(0, (value / max) * 100));
  const actualVariant = variant === 'default' ? getVariant(percentage) : variant;
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (percentage / 100) * circumference;

  return (
    <div className="circular-progress" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="circular-progress__svg">
        <circle
          className="circular-progress__track"
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
        />
        <circle
          className={`circular-progress__fill circular-progress__fill--${actualVariant}`}
          cx={size / 2}
          cy={size / 2}
          r={radius}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
        />
      </svg>
      <div className="circular-progress__content">
        <span className={`circular-progress__value circular-progress__value--${actualVariant}`}>
          {percentage.toFixed(0)}%
        </span>
        {label && <span className="circular-progress__label">{label}</span>}
      </div>
    </div>
  );
}

