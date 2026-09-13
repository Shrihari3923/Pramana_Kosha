import React, { useState } from 'react';
import { UploadCloud, FileCheck2, Lock } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Input } from '../ui/Input';
import { Button } from '../ui/Button';
import { computeSHA256 } from '../../utils/validation';

interface DocumentUploadProps {
  isOpen: boolean;
  onClose: () => void;
  caseId: string;
  onUpload: (
    caseId: string,
    file: File,
    metadata: { title: string; documentType: string; description: string; uploadedBy: string }
  ) => Promise<void>;
  currentUserName?: string;
}

export const DocumentUpload: React.FC<DocumentUploadProps> = ({
  isOpen,
  onClose,
  caseId,
  onUpload,
  currentUserName = 'Officer S. Jenkins',
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [documentType, setDocumentType] = useState('EVIDENTIARY_REPORT');
  const [description, setDescription] = useState('');
  const [computedHash, setComputedHash] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selected = e.target.files[0];
      setFile(selected);
      if (!title) {
        setTitle(selected.name.replace(/\.[^/.]+$/, ''));
      }
      // Compute hash in browser via Web Crypto API
      const buffer = await selected.arrayBuffer();
      const hash = await computeSHA256(buffer);
      setComputedHash(hash);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file || !title.trim()) return;

    setLoading(true);
    try {
      await onUpload(caseId, file, {
        title,
        documentType,
        description,
        uploadedBy: currentUserName,
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
      title="Upload Case Evidence Document"
      subtitle="Cryptographic SHA-256 calculation &amp; ledger seal commitment"
      icon={<UploadCloud size={20} />}
      maxWidth="lg"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        {/* File Drop Area */}
        <div className="border-2 border-dashed border-moss-border rounded-xl p-6 flex flex-col items-center justify-center text-center bg-surface-container-low/50 hover:bg-surface-container transition-colors">
          <input
            type="file"
            id="fileInput"
            className="hidden"
            onChange={handleFileChange}
            required
          />
          <label htmlFor="fileInput" className="cursor-pointer flex flex-col items-center">
            {file ? (
              <div className="flex flex-col items-center gap-2">
                <div className="w-12 h-12 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center">
                  <FileCheck2 size={24} />
                </div>
                <span className="text-sm font-bold text-forest-ink">{file.name}</span>
                <span className="text-xs text-on-surface-variant font-mono">
                  {(file.size / (1024 * 1024)).toFixed(2)} MB · {file.type || 'Binary Stream'}
                </span>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-2">
                <div className="w-12 h-12 rounded-full bg-surface-container text-primary flex items-center justify-center">
                  <UploadCloud size={24} />
                </div>
                <span className="text-sm font-bold text-forest-ink">
                  Click to select evidentiary file
                </span>
                <span className="text-xs text-on-surface-variant">
                  PDF, TIFF, JSON, MP4, or telemetry blobs up to 100MB
                </span>
              </div>
            )}
          </label>
        </div>

        {/* Live Computed SHA-256 Digest */}
        {computedHash && (
          <div className="p-3 bg-primary text-surface-bright rounded-lg flex flex-col gap-1 shadow-sm">
            <div className="flex items-center justify-between text-xs font-semibold text-secondary-fixed">
              <span className="flex items-center gap-1 font-mono uppercase">
                <Lock size={13} /> Real-Time SHA-256 Checksum Computed
              </span>
              <span className="text-[10px] bg-secondary px-1.5 py-0.5 rounded text-surface-bright">
                FIPS 180-4
              </span>
            </div>
            <div className="font-mono text-xs text-surface-bright break-all select-all pt-1">
              {computedHash}
            </div>
          </div>
        )}

        <Input
          label="Document Formal Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
          placeholder="e.g. Field Investigation Deposition & Aerial Map"
        />

        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
              Document Classification
            </label>
            <select
              value={documentType}
              onChange={(e) => setDocumentType(e.target.value)}
              className="h-10 px-3 bg-surface-container-low text-forest-ink border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            >
              <option value="EVIDENTIARY_REPORT">Evidentiary Report</option>
              <option value="SPECIAL_ENFORCEMENT_REPORT">Special Enforcement Report</option>
              <option value="TRANSPORT_MANIFEST">Transport Manifest</option>
              <option value="BALLISTICS_REPORT">Ballistics / Toxicology Report</option>
              <option value="COURT_FILING">Court Filing / Deposition</option>
            </select>
          </div>

          <Input
            label="Submitting Officer"
            value={currentUserName}
            disabled
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
            Forensic Description &amp; Scope
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={2}
            className="w-full p-3 bg-surface-container-low text-forest-ink placeholder:text-on-surface-variant/70 border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            placeholder="Key observations, sensor serials, or legal hold notes..."
          />
        </div>

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-moss-border/40">
          <Button variant="secondary" type="button" onClick={onClose} disabled={loading}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" loading={loading} disabled={!file}>
            Seal &amp; Commit to Chain
          </Button>
        </div>
      </form>
    </Modal>
  );
};
