'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  const [step, setStep] = useState<'email' | 'code'>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { shouldCreateUser: true },
    });
    setLoading(false);
    if (error) return setError(error.message);
    setStep('code');
  }

  async function verify(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(),
      token: code.trim(),
      type: 'email',
    });
    setLoading(false);
    if (error) return setError(error.message);
    router.push('/');
    router.refresh();
  }

  return (
    <>
      <div className="content no-nav" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', minHeight: '100dvh' }}>
        <div className="center" style={{ marginBottom: 28 }}>
          <div style={{ fontSize: 56 }}>🐾</div>
          <h1 style={{ fontSize: 34, margin: '8px 0 4px', letterSpacing: -1 }}>
            <span className="brand-mark">PAWD</span>
          </h1>
          <p className="muted" style={{ margin: 0 }}>Find your pet a friend nearby.</p>
        </div>

        {error && <div className="error-banner" style={{ marginBottom: 14 }}>{error}</div>}

        {step === 'email' ? (
          <form onSubmit={sendCode} className="stack">
            <div>
              <label htmlFor="email">Email address</label>
              <input
                id="email"
                type="email"
                inputMode="email"
                autoComplete="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <button className="btn btn-primary" disabled={loading || !email}>
              {loading ? 'Sending…' : 'Send login code'}
            </button>
            <p className="muted center" style={{ fontSize: 13 }}>
              We&apos;ll email you a 6-digit code. No password needed.
            </p>
          </form>
        ) : (
          <form onSubmit={verify} className="stack">
            <div className="notice">Code sent to {email}. Check your inbox.</div>
            <div>
              <label htmlFor="code">Login code</label>
              <input
                id="code"
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="Code from your email"
                maxLength={10}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                required
              />
            </div>
            <button className="btn btn-primary" disabled={loading || code.length < 6}>
              {loading ? 'Verifying…' : 'Verify & continue'}
            </button>
            <button type="button" className="btn btn-ghost" onClick={() => { setStep('email'); setCode(''); setError(null); }}>
              Use a different email
            </button>
          </form>
        )}

        <p className="muted center" style={{ fontSize: 12, marginTop: 24 }}>
          By continuing you confirm you are 18+ and agree to meet responsibly.
        </p>
      </div>
    </>
  );
}
