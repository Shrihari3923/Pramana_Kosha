import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { ProtectedRoute } from './ProtectedRoutes';
import { RoleRoute } from './RoleRoute';
import { Login } from '../pages/auth/Login';
import { Dashboard } from '../pages/Dashboard';
import { Cases } from '../pages/Cases';
import { CaseDetails } from '../pages/CaseDetails';
import { AuditLog } from '../pages/AuditLog';
import { Documents } from '../pages/Documents';
import { DocumentDetails } from '../pages/DocumentDetails';
import { Evidence } from '../pages/Evidence';
import { Security } from '../pages/Security';
import { Users } from '../pages/Users';
import { BlockchainLedger } from '../pages/BlockchainLedger';
import { Unauthorized } from '../pages/errors/Unauthorized';

export const AppRoutes: React.FC = () => {
  return (
    <Routes>
      {/* Public Route */}
      <Route path="/login" element={<Login />} />

      {/* Authenticated Protected Routes */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      <Route
        path="/cases"
        element={
          <ProtectedRoute>
            <Cases />
          </ProtectedRoute>
        }
      />

      <Route
        path="/cases/:id"
        element={
          <ProtectedRoute>
            <CaseDetails />
          </ProtectedRoute>
        }
      />

      <Route
        path="/audit"
        element={
          <ProtectedRoute>
            <AuditLog />
          </ProtectedRoute>
        }
      />

      <Route
        path="/documents"
        element={
          <ProtectedRoute>
            <Documents />
          </ProtectedRoute>
        }
      />

      <Route
        path="/documents/:id"
        element={
          <ProtectedRoute>
            <DocumentDetails />
          </ProtectedRoute>
        }
      />

      <Route
        path="/evidence"
        element={
          <ProtectedRoute>
            <Evidence />
          </ProtectedRoute>
        }
      />

      <Route
        path="/security"
        element={
          <ProtectedRoute>
            <Security />
          </ProtectedRoute>
        }
      />
      
      <Route
        path="/users"
        element={
          <RoleRoute allowedRoles={['ADMIN']}>
            <Users />
          </RoleRoute>
        }
      />

      <Route
        path="/blockchain"
        element={
          <ProtectedRoute>
            <BlockchainLedger />
          </ProtectedRoute>
        }
      />

      <Route path="/unauthorized" element={<Unauthorized />} />

      {/* Redirects */}
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
};
