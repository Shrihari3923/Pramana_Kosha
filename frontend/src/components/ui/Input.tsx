import React, { InputHTMLAttributes } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  helperText?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export const Input: React.FC<InputProps> = ({
  label,
  error,
  helperText,
  leftIcon,
  rightIcon,
  className = '',
  id,
  ...props
}) => {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className="w-full flex flex-col gap-1.5">
      {label && (
        <label
          htmlFor={inputId}
          className="text-xs font-semibold uppercase tracking-wider text-forest-ink flex items-center justify-between"
        >
          <span>{label}</span>
          {props.required && <span className="text-error text-xs">*</span>}
        </label>
      )}
      <div className="relative flex items-center">
        {leftIcon && (
          <div className="absolute left-3 text-on-surface-variant flex items-center pointer-events-none">
            {leftIcon}
          </div>
        )}
        <input
          id={inputId}
          className={`w-full h-10 bg-surface-container-low text-forest-ink placeholder:text-on-surface-variant/70 border rounded-lg text-sm transition-all focus:outline-none focus:bg-surface-bright focus:border-secondary focus:ring-2 focus:ring-secondary/20 disabled:bg-surface-container-high disabled:cursor-not-allowed ${
            leftIcon ? 'pl-10' : 'pl-3.5'
          } ${rightIcon ? 'pr-10' : 'pr-3.5'} ${
            error ? 'border-error focus:ring-error/20' : 'border-moss-border/60'
          } ${className}`}
          {...props}
        />
        {rightIcon && (
          <div className="absolute right-3 text-on-surface-variant flex items-center">
            {rightIcon}
          </div>
        )}
      </div>
      {error ? (
        <span className="text-xs text-error font-medium">{error}</span>
      ) : helperText ? (
        <span className="text-xs text-on-surface-variant">{helperText}</span>
      ) : null}
    </div>
  );
};
