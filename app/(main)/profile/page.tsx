'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import type { Owner } from '@/lib/types';

export default function ProfilePage() {
  const supabase = createClient();
  const router = useRouter();
  const [owner, setOwner] = useState<Owner | null>(null);
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [area, setArea] = useState('');
  const [saved, setSaved] = useState(false);
  const [locMsg, setLocMsg] = useState('');

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { router.push('/login'); return; }
      setEmail(user.email ?? '');
      const { data } = await supabase.from('owners').select('*').eq('id', user.id).single();
      if (data) {
        setOwner(data as Owner);
        setDisplayName((data as Owner).display_name);
        setArea((data as Owner).area ?? '');
      }
    })();
  }, [router, supabase]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!owner) return;
    await supabase.from('owners').update({ display_name: displayName.trim() || 'Pet Owner', area: area.trim() || null }).eq('id', owner.id);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  }

  function updateLocation() {
    setLocMsg('Getting location…');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        await supabase.rpc('set_my_location', { p_lat: pos.coords.latitude, p_lng: pos.coords.longitude });
        setLocMsg('✓ Location updated');
      },
      () => setLocMsg('Could not get location.'),
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  async function signOut() {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  }

  if (!owner) return <div className="spinner" />;

  return (
    <>
      <div className="appbar"><h1>Profile</h1></div>
      <div className="content">
        <form onSubmit={save} className="stack">
          <div>
            <label>Email</label>
            <input value={email} disabled />
          </div>
          <div>
            <label htmlFor="dn">Display name</label>
            <input id="dn" value={displayName} onChange={(e) => setDisplayName(e.target.value)} />
          </div>
          <div>
            <label htmlFor="area">Area</label>
            <input id="area" value={area} onChange={(e) => setArea(e.target.value)} placeholder="e.g. Osu, Accra" />
          </div>
          {saved && <div className="notice">Saved ✓</div>}
          <button className="btn btn-primary">Save profile</button>
        </form>

        <div className="stack" style={{ marginTop: 20 }}>
          <label>Location</label>
          <button className="btn btn-ghost" onClick={updateLocation}>📍 Update my location</button>
          {locMsg && <p className="muted" style={{ fontSize: 13 }}>{locMsg}</p>}
        </div>

        <div className="stack" style={{ marginTop: 24 }}>
          <button className="btn btn-danger" onClick={signOut}>Sign out</button>
        </div>

        <p className="muted center" style={{ fontSize: 12, marginTop: 24 }}>
          PAWD v1.0 · Meet responsibly · Report concerns in-chat.<br />
          Your exact location is never shown to others — only approximate distance.
        </p>
      </div>
    </>
  );
}
