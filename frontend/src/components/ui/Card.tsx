import { ReactNode } from 'react';
import './Card.css';

interface CardProps {
  children: ReactNode;
  title?: string;
  subtitle?: string;
  action?: ReactNode;
  className?: string;
  padding?: 'none' | 'sm' | 'md' | 'lg';
}

export function Card({ children, title, subtitle, action, className = '', padding = 'md' }: CardProps) {
  return (
    <div className={`card card--padding-${padding} ${className}`}>
      {(title || subtitle || action) && (
        <div className="card__header">
          <div className="card__header-left">
            {title && <h3 className="card__title">{title}</h3>}
            {subtitle && <p className="card__subtitle">{subtitle}</p>}
          </div>
          {action && <div className="card__header-action">{action}</div>}
        </div>
      )}
      <div className="card__content">{children}</div>
    </div>
  );
}

