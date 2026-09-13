import React, { useState } from 'react';
import { PackagePlus } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Input } from '../ui/Input';
import { Button } from '../ui/Button';

interface EvidenceUploadProps {
  isOpen: boolean;
  onClose: () => void;
  caseId: string;
  onSubmit: (data: {
    item_number: string;
    name: string;
    category: string;
    description: string;
    location: string;
  }) => Promise<void>;
}

export const EvidenceUpload: React.FC<EvidenceUploadProps> = ({
  isOpen,
  onClose,
  onSubmit,
}) => {
  const [itemNumber, setItemNumber] = useState(`EVI-2026-${Math.floor(100 + Math.random() * 900)}`);
  const [name, setName] = useState('');
  const [category, setCategory] = useState('PHYSICAL_EQUIPMENT');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('District Evidence Locker B-4');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setLoading(true);
    try {
      await onSubmit({
        item_number: itemNumber,
        name,
        category,
        description,
        location,
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
      title="Log Physical or Digital Evidence"
      subtitle="Issue tamper-evident custody seal &amp; seed genesis transaction"
      icon={<PackagePlus size={20} />}
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Evidence Identifier Tag"
          value={itemNumber}
          onChange={(e) => setItemNumber(e.target.value)}
          required
        />

        <Input
          label="Item Name / Asset Model"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          placeholder="e.g. Caterpillar Excavator Electronic Key Module"
        />

        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
              Category
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="h-10 px-3 bg-surface-container-low text-forest-ink border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            >
              <option value="PHYSICAL_EQUIPMENT">Physical Machinery</option>
              <option value="DIGITAL_FORENSICS">Digital Forensics / Storage</option>
              <option value="BIOLOGICAL_SPECIMEN">Botanical / Biological Sample</option>
              <option value="DOCUMENTARY_EVIDENCE">Physical Ledger / Manifest</option>
            </select>
          </div>

          <Input
            label="Secure Storage Location"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            required
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
            Forensic Description &amp; Integrity Seals
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="w-full p-3 bg-surface-container-low text-forest-ink placeholder:text-on-surface-variant/70 border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            placeholder="Serial numbers, physical condition, tamper-evident bag numbers..."
          />
        </div>

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-moss-border/40">
          <Button variant="secondary" type="button" onClick={onClose} disabled={loading}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" loading={loading}>
            Register Sealed Evidence
          </Button>
        </div>
      </form>
    </Modal>
  );
};
