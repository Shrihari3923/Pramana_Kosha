import React from 'react';
import { Badge } from '../ui/Badge';
import { CaseStatus } from '../../types';

interface Props {
  status: CaseStatus;
}

export const CaseStatusBadge: React.FC<Props> = ({ status }) => {
  return <Badge status={status} />;
};
