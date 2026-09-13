import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { Role } from '../types';
import { Unauthorized } from '../pages/errors/Unauthorized';

interface RoleRouteProps {
  children: React.ReactNode;
  allowedRoles: Role[];
}

export const RoleRoute: React.FC<RoleRouteProps> = ({ children, allowedRoles }) => {
  const { isAuthenticated, isLoading, role } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#FFF9ED] flex flex-col items-center justify-center">
        <div className="animate-spin w-10 h-10 border-3 border-[#0E2520] border-t-transparent rounded-full mb-4"></div>
        <p className="text-xs font-semibold text-[#0E2520] tracking-wider uppercase">
          Verifying Cryptographic Session...
        </p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  const userRoleUpper = String(role || '').toUpperCase();
  const isAllowed = allowedRoles.some((r) => r.toUpperCase() === userRoleUpper);

  if (!role || !isAllowed) {
    return <Unauthorized />;
  }

  return <>{children}</>;
};
