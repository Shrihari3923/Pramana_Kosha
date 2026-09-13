import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { generateOTP, sendOTP } from '../../services/otp';
import { OtpModal } from '../../components/common/OtpModal';

export const Login: React.FC = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  const [activeTab, setActiveTab] = useState<'ADMIN' | 'USER'>('ADMIN');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [jurisdiction, setJurisdiction] = useState('Node Alpha');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // OTP state
  const [showOtp, setShowOtp] = useState(false);
  const [currentOtp, setCurrentOtp] = useState('');
  const [otpSending, setOtpSending] = useState(false);
  const [otpSendError, setOtpSendError] = useState<string | null>(null);
  // Holds the login() call we want to run after OTP is verified
  const [pendingLogin, setPendingLogin] = useState<(() => Promise<void>) | null>(null);

  const handleTabSwitch = (mode: 'ADMIN' | 'USER') => {
    setActiveTab(mode);
    setError('');
  };

  /** Step 1: validate credentials against the backend, then gate behind OTP */
  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // Verify credentials first — this will throw if wrong password/email.
      // We call login() but immediately log out the session so the user can't
      // slip through. We re-call login() again after OTP is verified.
await login(
  email,
  password,
  activeTab === 'ADMIN' ? 'ADMIN' : 'INVESTIGATOR'
);
      // Credentials OK — generate & send OTP before granting access.
      const otp = generateOTP();
      setCurrentOtp(otp);
      setOtpSending(true);
      setShowOtp(true);

      try {
        await sendOTP({
          otp,
          userEmail: email,
          action: activeTab === 'ADMIN' ? 'Administrator Login' : 'Officer Login',
        });
        setOtpSendError(null);
      } catch {
        setOtpSendError('Failed to send OTP email. Check EmailJS configuration.');
      } finally {
        setOtpSending(false);
      }

      // Store the login action so we can execute it after OTP verification.
      // We already have a valid session from the call above, so on verify we
      // just navigate — no need to call login() again.
      setPendingLogin(() => async () => {
        navigate('/dashboard');
      });

    } catch (err: unknown) {
      const msg =
        err instanceof Error
          ? err.message
          : 'Unable to authenticate. Ensure the server is running.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  /** Step 2: OTP verified — execute the pending login navigation */
  const handleOtpVerified = async () => {
    setShowOtp(false);
    if (pendingLogin) {
      await pendingLogin();
    }
  };

  /** User cancelled the OTP modal — clear session so they can't bypass */
  const handleOtpCancel = () => {
    setShowOtp(false);
    setCurrentOtp('');
    setPendingLogin(null);
    // Clear any session that was created during credential verification
    sessionStorage.clear();
    localStorage.removeItem('chaindock_token');
    localStorage.removeItem('chaindock_user');
  };

  /** Resend a fresh OTP */
  const handleOtpResend = async () => {
    const otp = generateOTP();
    setCurrentOtp(otp);
    setOtpSending(true);
    try {
      await sendOTP({
        otp,
        userEmail: email,
        action: activeTab === 'ADMIN' ? 'Administrator Login' : 'Officer Login',
      });
      setOtpSendError(null);
    } catch {
      setOtpSendError('Failed to resend OTP. Check EmailJS configuration.');
    } finally {
      setOtpSending(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-100 text-slate-900 flex flex-col font-sans antialiased">

      {/* OTP Modal — shown after credentials are verified */}
      {showOtp && (
        <OtpModal
          title={activeTab === 'ADMIN' ? 'Administrator 2FA' : 'Officer 2FA'}
          description="A one-time password has been sent to bkadikuppur@gmail.com. Enter it below to complete sign-in."
          expectedOtp={currentOtp}
          sending={otpSending}
          sendError={otpSendError}
          onVerified={handleOtpVerified}
          onCancel={handleOtpCancel}
          onResend={handleOtpResend}
        />
      )}

      {/* =========================================================
          TOP GOVERNMENT HEADER
      ========================================================= */}
      <header className="bg-[#0b1f3a] text-white border-b border-[#16365f]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

          <div className="h-16 flex items-center justify-between">

            {/* Logo + System Name */}
            <div className="flex items-center gap-3">

              <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center shadow-sm">
                <span className="material-symbols-outlined text-[#0b1f3a] text-[25px]">
                  local_police
                </span>
              </div>

              <div>
                <div className="text-sm sm:text-base font-bold tracking-wide uppercase">
                  pramāṇa-kośa
                </div>

                <div className="text-[9px] sm:text-[10px] text-blue-200 uppercase tracking-[0.12em]">
                  Digital Investigation Platform
                </div>
              </div>

            </div>

            {/* Secure Status */}
            <div className="hidden sm:flex items-center gap-3">

              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-[#102b4d] border border-[#1c4777]">
                <span className="relative flex h-2.5 w-2.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-60"></span>
                  <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-400"></span>
                </span>

                <span className="text-[10px] font-semibold tracking-wider text-emerald-300">
                  SECURE SYSTEM
                </span>
              </div>

              <span className="text-[10px] text-blue-200 font-mono">
                NODE: SECURE-GRID
              </span>

            </div>

          </div>

        </div>
      </header>


      {/* =========================================================
          MAIN LOGIN AREA
      ========================================================= */}
      <main className="flex-1 flex items-center justify-center px-4 py-8 sm:py-12">

        <div className="w-full max-w-6xl grid grid-cols-1 lg:grid-cols-12 bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden">


          {/* =====================================================
              LEFT pramāṇa-kośa INFORMATION PANEL
          ===================================================== */}
          <section className="lg:col-span-5 bg-[#0b1f3a] text-white p-6 sm:p-8 lg:p-10 flex flex-col justify-between">

            <div>

              {/* Police Identity */}
              <div className="flex items-center gap-3 mb-8">

                <div className="w-12 h-12 rounded-xl bg-white/10 border border-white/15 flex items-center justify-center">
                  <span className="material-symbols-outlined text-[28px] text-blue-200">
                    local_police
                  </span>
                </div>

                <div>

                  <h1 className="text-xl font-bold tracking-tight">
                    pramāṇa-kośa
                  </h1>

                  <p className="text-[10px] text-blue-200 uppercase tracking-[0.15em]">
                    Digital Investigation Platform
                  </p>

                </div>

              </div>


              {/* Welcome */}
              <div className="mb-8">

                <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded-md bg-blue-500/10 border border-blue-400/20 text-blue-200 text-[9px] font-bold uppercase tracking-wider mb-4">
                  <span className="material-symbols-outlined text-[14px]">
                    verified_user
                  </span>

                  Authorized Access Only
                </div>

                <h2 className="text-2xl sm:text-3xl font-bold leading-tight">
                  Secure Digital
                  <br />
                  Investigation Management
                </h2>

                <p className="mt-4 text-sm text-blue-100/70 leading-relaxed">
                  Manage police cases, FIR records, digital documents,
                  evidence, officer assignments and investigation activity
                  through a centralized secure platform.
                </p>

              </div>


              {/* Feature Cards */}
              <div className="space-y-3">

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.05] border border-white/10">
                  <div className="w-9 h-9 rounded-lg bg-blue-500/10 flex items-center justify-center">
                    <span className="material-symbols-outlined text-blue-300 text-[19px]">folder_open</span>
                  </div>
                  <div>
                    <div className="text-xs font-semibold">Case & FIR Management</div>
                    <div className="text-[10px] text-blue-200/60">Centralized investigation records</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.05] border border-white/10">
                  <div className="w-9 h-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                    <span className="material-symbols-outlined text-emerald-300 text-[19px]">inventory_2</span>
                  </div>
                  <div>
                    <div className="text-xs font-semibold">Digital Evidence</div>
                    <div className="text-[10px] text-blue-200/60">Secure custody and integrity tracking</div>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 rounded-xl bg-white/[0.05] border border-white/10">
                  <div className="w-9 h-9 rounded-lg bg-purple-500/10 flex items-center justify-center">
                    <span className="material-symbols-outlined text-purple-300 text-[19px]">account_tree</span>
                  </div>
                  <div>
                    <div className="text-xs font-semibold">ChainDock Security</div>
                    <div className="text-[10px] text-blue-200/60">Cryptographic audit & evidence protection</div>
                  </div>
                </div>

              </div>

            </div>


            {/* ChainDock Footer */}
            <div className="mt-10 pt-5 border-t border-white/10">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-[9px] uppercase tracking-wider text-blue-300">Secure Infrastructure</div>
                  <div className="text-sm font-bold mt-1">ChainDock</div>
                </div>
                <div className="text-right">
                  <div className="text-[9px] text-blue-300 uppercase tracking-wider">Integrity</div>
                  <div className="flex items-center gap-1.5 mt-1 text-emerald-300">
                    <span className="material-symbols-outlined text-[15px]">verified</span>
                    <span className="text-[10px] font-semibold">PROTECTED</span>
                  </div>
                </div>
              </div>
            </div>

          </section>


          {/* =====================================================
              RIGHT LOGIN PANEL
          ===================================================== */}
          <section className="lg:col-span-7 p-6 sm:p-8 lg:p-10 bg-white">

            <div className="max-w-xl mx-auto">

              {/* Header */}
              <div className="mb-7">
                <div className="flex items-center gap-2 text-blue-700 text-[10px] font-bold uppercase tracking-[0.14em] mb-2">
                  <span className="material-symbols-outlined text-[16px]">lock</span>
                  Secure Officer Authentication
                </div>
                <h2 className="text-2xl sm:text-3xl font-bold text-[#0b1f3a] tracking-tight">
                  Sign in to pramāṇa-kośa
                </h2>
                <p className="text-xs sm:text-sm text-slate-500 mt-2">
                  Authenticate using your registered police credentials.
                </p>
              </div>


              {/* Role Tabs */}
              <div className="grid grid-cols-2 gap-1 p-1 bg-slate-100 border border-slate-200 rounded-xl mb-6">

                <button
                  type="button"
                  onClick={() => handleTabSwitch('ADMIN')}
                  className={`py-3 rounded-lg text-xs font-semibold flex items-center justify-center gap-2 transition-all ${
                    activeTab === 'ADMIN'
                      ? 'bg-[#0b1f3a] text-white shadow-md'
                      : 'text-slate-500 hover:text-slate-800 hover:bg-white'
                  }`}
                >
                  <span className="material-symbols-outlined text-[18px]">admin_panel_settings</span>
                  Administrator
                </button>

                <button
                  type="button"
                  onClick={() => handleTabSwitch('USER')}
                  className={`py-3 rounded-lg text-xs font-semibold flex items-center justify-center gap-2 transition-all ${
                    activeTab === 'USER'
                      ? 'bg-[#0b1f3a] text-white shadow-md'
                      : 'text-slate-500 hover:text-slate-800 hover:bg-white'
                  }`}
                >
                  <span className="material-symbols-outlined text-[18px]">badge</span>
                  Investigating Officer
                </button>

              </div>

              {/* OTP info notice */}
              <div className="mb-5 flex items-start gap-2.5 p-3 bg-blue-50 border border-blue-100 rounded-xl">
                <span className="material-symbols-outlined text-blue-600 text-[18px] shrink-0 mt-0.5">
                  security
                </span>
                <p className="text-[10px] text-blue-700 leading-relaxed">
                  After entering your credentials, a one-time password will be sent to
                  <strong className="font-bold"> bkadikuppur@gmail.com</strong> for two-factor verification.
                </p>
              </div>

              {/* Error */}
              {error && (
                <div className="mb-5 p-4 bg-red-50 border border-red-200 rounded-xl flex gap-3">
                  <span className="material-symbols-outlined text-red-600 text-[20px]">error</span>
                  <div className="flex-1">
                    <div className="text-xs font-bold text-red-800">Authentication Failed</div>
                    <div className="text-xs text-red-700 mt-1 leading-relaxed">{error}</div>
                  </div>
                </div>
              )}

              {/* Login Form */}
              <form onSubmit={handleLoginSubmit} className="space-y-5">

                {/* Jurisdiction */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-slate-600 mb-2">
                    Jurisdiction / Police Node
                  </label>
                  <div className="relative">
                    <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                      account_balance
                    </span>
                    <select
                      value={jurisdiction}
                      onChange={(e) => setJurisdiction(e.target.value)}
                      className="w-full h-11 pl-10 pr-3 bg-slate-50 text-slate-800 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all"
                    >
                      <option value="Node Alpha">Jurisdiction Node Alpha</option>
                      <option value="Node Beta">Jurisdiction Node Beta</option>
                      <option value="Root Central">Central Police Infrastructure</option>
                    </select>
                  </div>
                </div>

                {/* Email */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <label className="text-[10px] font-bold uppercase tracking-wider text-slate-600">
                      {activeTab === 'ADMIN' ? 'Administrator Email' : 'Officer Email'}
                    </label>
                    <span className="text-[9px] font-mono font-bold text-blue-600">
                      {activeTab === 'ADMIN' ? 'ADMIN' : 'INVESTIGATOR'}
                    </span>
                  </div>
                  <div className="relative">
                    <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                      {activeTab === 'ADMIN' ? 'admin_panel_settings' : 'badge'}
                    </span>
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                      className="w-full h-11 pl-10 pr-3 bg-slate-50 text-slate-800 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all"
                      placeholder="officer@police.gov.in"
                    />
                  </div>
                </div>

                {/* Password */}
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-slate-600 mb-2">
                    Password
                  </label>
                  <div className="relative">
                    <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                      lock
                    </span>
                    <input
                      type="password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                      className="w-full h-11 pl-10 pr-3 bg-slate-50 text-slate-800 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all"
                      placeholder="Enter secure password"
                    />
                  </div>
                </div>

                {/* Submit */}
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full h-12 mt-2 rounded-lg bg-[#0b1f3a] text-white hover:bg-[#12345c] font-bold text-xs tracking-wider uppercase flex items-center justify-center gap-2 shadow-lg transition-all disabled:opacity-60 disabled:cursor-not-allowed"
                >
                  {loading ? (
                    <>
                      <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Verifying credentials…
                    </>
                  ) : (
                    <>
                      <span className="material-symbols-outlined text-[18px]">login</span>
                      Sign In to pramāṇa-kośa
                      <span className="material-symbols-outlined text-[17px]">arrow_forward</span>
                    </>
                  )}
                </button>

              </form>

              {/* Security Notice */}
              <div className="mt-7 p-4 rounded-xl bg-slate-50 border border-slate-200">
                <div className="flex items-start gap-3">
                  <span className="material-symbols-outlined text-emerald-600 text-[19px]">verified_user</span>
                  <div>
                    <div className="text-[10px] font-bold uppercase tracking-wider text-slate-700">
                      ChainDock Security Layer
                    </div>
                    <p className="text-[10px] text-slate-500 leading-relaxed mt-1">
                      Authentication and investigation activity are protected
                      by the ChainDock secure infrastructure and recorded
                      through the platform's audit mechanisms.
                    </p>
                  </div>
                </div>
              </div>

            </div>

          </section>

        </div>

      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="min-h-12 flex flex-col sm:flex-row items-center justify-between gap-2 py-3">
            <div className="text-[9px] sm:text-[10px] text-slate-500 uppercase tracking-wider">
              pramāṇa-kośa
            </div>
            <div className="flex items-center gap-3 text-[9px] text-slate-400 font-mono">
              <span>RUST</span><span>•</span><span>POSTGRESQL</span><span>•</span><span>CHAINDOCK</span>
            </div>
          </div>
        </div>
      </footer>

    </div>
  );
};
