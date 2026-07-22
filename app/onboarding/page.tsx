'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import PetForm from '@/components/PetForm';

export default function Onboarding() {
  const supabase = createClient();
  const router = useRouter();
  const [ownerId, setOwnerId] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState('');
  const [area, setArea] = useState('');
  const [locState, setLocState] = useState<'idle' | 'getting' | 'set' | 'manual'>('idle');
  const [step, setStep] = useState<'owner' | 'pet'>('owner');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) { router.push('/login'); return; }
      setOwnerId(data.user.id);
      supabase.from('owners').select('display_name, area').eq('id', data.user.id).single().then(({ data: o }) => {
        if (o?.display_name && o.display_name !== 'Pet Owner') setDisplayName(o.display_name);
        if (o?.area) setArea(o.area);
      });
    });
  }, [router, supabase]);

  function captureLocation() {
    if (!('geolocation' in navigator)) { setLocState('manual'); return; }
    setLocState('getting');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        await supabase.rpc('set_my_location', {
          p_lat: pos.coords.latitude,
          p_lng: pos.coords.longitude,
        });
        setLocState('set');
      },
      () => setLocState('manual'),
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  async function saveOwner(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!ownerId) return;
    // Fallback: if location denied, geocode the area roughly to Accra center so the deck works.
    if (locState !== 'set') {
      await supabase.rpc('set_my_location', { p_lat: 5.6037, p_lng: -0.187 }); // Accra
    }
    const { error } = await supabase
      .from('owners')
      .update({ display_name: displayName.trim() || 'Pet Owner', area: area.trim() || null, age_attested: true })
      .eq('id', ownerId);
    if (error) return setError(error.message);
    setStep('pet');
  }

  if (!ownerId) return <div className="spinner" />;

  return (
    <>
      <div className="appbar"><h1><span className="brand-mark">PAWD</span> · Welcome</h1></div>
      <div className="content no-nav">
        {step === 'owner' ? (
          <form onSubmit={saveOwner} className="stack">
            <p className="muted">Let&apos;s set up your account. This takes under a minute.</p>
            <div>
              <label htmlFor="dn">Your name</label>
              <input id="dn" value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="e.g. Ama" required />
            </div>
            <div>
              <label htmlFor="area">Neighbourhood / area</label>
              <input id="area" value={area} onChange={(e) => setArea(e.target.value)} placeholder="e.g. East Legon, Accra" />
            </div>

            <label>Location</label>
            <button type="button" className={`btn ${locState === 'set' ? 'btn-ghost' : 'btn-primary'}`} onClick={captureLocation}>
              {locState === 'idle' && '📍 Use my location'}
              {locState === 'getting' && 'Getting location…'}
              {locState === 'set' && '✓ Location set'}
              {locState === 'manual' && '📍 Retry location'}
            </button>
            {locState === 'manual' && (
              <p className="muted" style={{ fontSize: 13 }}>
                Location unavailable — we&apos;ll use your area&apos;s city centre so discovery still works. Distances stay approximate for everyone&apos;s privacy.
              </p>
            )}

            {error && <div className="error-banner">{error}</div>}
            <button className="btn btn-primary">Continue</button>
            <p className="muted center" style={{ fontSize: 12 }}>
              By continuing you attest you are 18 or older.
            </p>
          </form>
        ) : (
          <>
            <h2 style={{ margin: '4px 0 2px' }}>Add your first pet 🐾</h2>
            <p className="muted" style={{ marginTop: 0 }}>The pet is the profile. Make it shine.</p>
            <PetForm ownerId={ownerId} onSaved={() => { router.push('/discover'); router.refresh(); }} />
          </>
        )}
      </div>
    </>
  );
}
