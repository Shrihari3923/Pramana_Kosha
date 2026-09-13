import React, { useState } from 'react';
import { RotateCcw } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Input } from '../ui/Input';
import { Button } from '../ui/Button';
import { EvidenceItem } from '../../types';

interface ChainOfCustodyLogProps {
  isOpen: boolean;
  onClose: () => void;
  evidenceItem: EvidenceItem | null;
  onTransfer: (
    evidenceId: string,
    data: { newCustodian: string; location: string; notes: string; actor: string }
  ) => Promise<void>;
  currentUser?: string;
}

export const ChainOfCustodyLog: React.FC<ChainOfCustodyLogProps> = ({
  isOpen,
  onClose,
  evidenceItem,
  onTransfer,
  currentUser = 'Officer S. Jenkins',
}) => {
  const [newCustodian, setNewCustodian] = useState('');
  const [location, setLocation] = useState('Central Forensic Evidence Vault 2');
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);

  if (!evidenceItem) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCustodian.trim()) return;

    setLoading(true);
    try {
      await onTransfer(evidenceItem.id, {
        newCustodian,
        location,
        notes,
        actor: currentUser,
      });
      onClose();
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Transfer Evidentiary Chain of Custody"
      subtitle={`Item: ${evidenceItem.name} (${evidenceItem.item_number})`}
      icon={<RotateCcw size={20} />}
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="p-3 bg-surface-container-low rounded-lg flex flex-col gap-1 text-xs">
          <span className="text-[10px] uppercase font-bold text-on-surface-variant">
            Current Custodian
          </span>
          <span className="font-bold text-forest-ink">{evidenceItem.custodian}</span>
          <span className="text-on-surface-variant font-mono">
            Current Location: {evidenceItem.location}
          </span>
        </div>

        <Input
          label="New Receiving Custodian"
          value={newCustodian}
          onChange={(e) => setNewCustodian(e.target.value)}
          required
          placeholder="e.g. Insp. M. Laurent (Badge #CD-4420)"
        />

        <Input
          label="New Secure Facility / Chamber"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
          required
          placeholder="e.g. State Forensic Science Laboratory, Room 104"
        />

        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
            Custody Transfer Reason &amp; Seal Verification Notes
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            className="w-full p-3 bg-surface-container-low text-forest-ink placeholder:text-on-surface-variant/70 border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            placeholder="Verified physical tamper-evident seal intact. Handed over for destructive laboratory spectrography..."
          />
        </div>

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-moss-border/40">
          <Button variant="secondary" type="button" onClick={onClose} disabled={loading}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" loading={loading}>
            Authenticate &amp; Commit Transfer
          </Button>
        </div>
      </form>
    </Modal>
  );
};
