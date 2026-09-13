import React, { HTMLAttributes } from 'react';

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'elevated' | 'surface' | 'container' | 'bordered';
  hoverable?: boolean;
}

export const Card: React.FC<CardProps> = ({
  children,
  variant = 'surface',
  hoverable = false,
  className = '',
  ...props
}) => {
  const variantClasses = {
    surface: 'bg-surface-bright border border-moss-border/70 text-forest-ink shadow-sm',
    elevated: 'bg-surface-bright border border-moss-border text-forest-ink shadow-md',
    container: 'bg-surface-container text-forest-ink border border-moss-border/40',
    bordered: 'bg-surface-container-low border border-moss-border text-forest-ink',
  };

  return (
    <div
      className={`rounded-xl p-6 ${variantClasses[variant]} ${
        hoverable ? 'hover:shadow-md hover:border-secondary transition-all duration-200 cursor-pointer' : ''
      } ${className}`}
      {...props}
    >
      {children}
    </div>
  );
};
