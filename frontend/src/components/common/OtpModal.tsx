import React, { useState, useEffect, useRef } from 'react';

interface OtpModalProps {
  /** Title shown at top of the modal */
  title?: string;
  /** Subtitle / description line */
  description?: string;
  /** Called when user submits the correct OTP */
  onVerified: () => void;
  /** Called when user cancels */
  onCancel: () => void;
  /** The OTP value to validate against */
  expectedOtp: string;
  /** Whether the parent is currently sending the OTP */
  sending?: boolean;
  /** Error from the parent (e.g. email send failed) */
  sendError?: string | null;
  /** Callback to request a new OTP */
  onResend?: () => void;
}

export const OtpModal: React.FC<OtpModalProps> = ({
  title = 'Verify Your Identity',
  description = 'An OTP has been sent to bkadikuppur@gmail.com. Enter it below to continue.',
  onVerified,
  onCancel,
  expectedOtp,
  sending = false,
  sendError = null,
  onResend,
}) => {
  const [digits, setDigits] = useState<string[]>(['', '', '', '', '', '']);
  const [error, setError] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(60);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  // Countdown timer for resend
  useEffect(() => {
    if (resendCooldown <= 0) return;
    const t = setInterval(() => setResendCooldown((c) => c - 1), 1000);
    return () => clearInterval(t);
  }, [resendCooldown]);

  const enteredOtp = digits.join('');

  const handleDigit = (i: number, value: string) => {
    const v = value.replace(/\D/g, '').slice(-1);
    const next = [...digits];
    next[i] = v;
    setDigits(next);
    setError(null);
    if (v && i < 5) inputRefs.current[i + 1]?.focus();
  };

  const handleKeyDown = (i: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) {
      inputRefs.current[i - 1]?.focus();
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    const text = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (text.length === 6) {
      setDigits(text.split(''));
      inputRefs.current[5]?.focus();
    }
  };

  const handleVerify = () => {
    if (enteredOtp.length < 6) {
      setError('Please enter all 6 digits.');
      return;
    }
    setVerifying(true);
    setTimeout(() => {
      if (enteredOtp === expectedOtp) {
        setVerifying(false);
        onVerified();
      } else {
        setVerifying(false);
        setError('Incorrect OTP. Please try again.');
        setDigits(['', '', '', '', '', '']);
        inputRefs.current[0]?.focus();
      }
    }, 400);
  };

  const handleResend = () => {
    if (resendCooldown > 0 || !onResend) return;
    setDigits(['', '', '', '', '', '']);
    setError(null);
    setResendCooldown(60);
    onResend();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-2xl border border-slate-200 overflow-hidden">

        {/* Header */}
        <div className="bg-[#0b1f3a] px-6 py-5 text-white">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center">
              <span className="material-symbols-outlined text-[22px] text-blue-200">
                lock
              </span>
            </div>
            <div>
              <h2 className="text-sm font-bold tracking-tight">{title}</h2>
              <p className="text-[10px] text-blue-200 mt-0.5 uppercase tracking-wider">
                Two-Factor Authentication
              </p>
            </div>
          </div>
        </div>

        {/* Body */}
        <div className="px-6 py-6">

          {sending ? (
            <div className="flex flex-col items-center gap-3 py-6">
              <div className="w-10 h-10 border-4 border-blue-100 border-t-blue-700 rounded-full animate-spin" />
              <p className="text-sm text-slate-600 font-medium">Sending OTP…</p>
            </div>
          ) : (
            <>
              <p className="text-xs text-slate-600 mb-5 leading-relaxed">
                {description}
              </p>

              {/* 6-digit input */}
              <div className="flex justify-center gap-2 mb-5" onPaste={handlePaste}>
                {digits.map((d, i) => (
                  <input
                    key={i}
                    ref={(el) => { inputRefs.current[i] = el; }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={d}
                    onChange={(e) => handleDigit(i, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(i, e)}
                    className={`w-11 h-13 text-center text-xl font-bold border-2 rounded-xl outline-none transition-all
                      ${d ? 'border-blue-600 bg-blue-50 text-blue-900' : 'border-slate-200 bg-slate-50 text-slate-800'}
                      focus:border-blue-500 focus:ring-2 focus:ring-blue-100`}
                    style={{ height: '52px' }}
                    autoFocus={i === 0}
                  />
                ))}
              </div>

              {/* Error */}
              {(error || sendError) && (
                <div className="mb-4 flex items-center gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-xs text-red-700 font-medium">
                  <span className="material-symbols-outlined text-[16px]">error</span>
                  {error || sendError}
                </div>
              )}

              {/* Actions */}
              <button
                onClick={handleVerify}
                disabled={verifying || enteredOtp.length < 6}
                className="w-full h-11 rounded-lg bg-[#0b1f3a] text-white text-xs font-bold uppercase tracking-wider hover:bg-[#12345c] disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
              >
                {verifying ? (
                  <>
                    <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    Verifying…
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[16px]">verified_user</span>
                    Verify &amp; Continue
                  </>
                )}
              </button>

              <div className="flex items-center justify-between mt-4">
                <button
                  type="button"
                  onClick={onCancel}
                  className="text-xs text-slate-500 hover:text-slate-700 font-medium"
                >
                  Cancel
                </button>

                <button
                  type="button"
                  onClick={handleResend}
                  disabled={resendCooldown > 0 || !onResend}
                  className="text-xs font-semibold text-blue-600 hover:text-blue-800 disabled:text-slate-400 disabled:cursor-not-allowed"
                >
                  {resendCooldown > 0
                    ? `Resend in ${resendCooldown}s`
                    : 'Resend OTP'}
                </button>
              </div>
            </>
          )}
        </div>

      </div>
    </div>
  );
};
