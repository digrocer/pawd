import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { photoUrl, type MatchRow } from '@/lib/types';

export const dynamic = 'force-dynamic';

function timeAgo(iso: string | null): string {
  if (!iso) return '';
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return 'now';
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}

export default async function MatchesPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data } = await supabase.rpc('my_matches');
  const matches = (data as MatchRow[]) ?? [];

  return (
    <>
      <div className="appbar"><h1>Matches</h1></div>
      <div className="content">
        {matches.length === 0 ? (
          <div className="empty">
            <div className="big">💛</div>
            <h3>No matches yet</h3>
            <p>Head to Discover and start liking pets. When it&apos;s mutual, they&apos;ll show up here.</p>
            <Link href="/discover" className="btn btn-primary" style={{ maxWidth: 220, margin: '12px auto 0' }}>Go to Discover</Link>
          </div>
        ) : (
          matches.map((m) => {
            const img = photoUrl('pet-photos', m.other_primary_photo);
            return (
              <Link key={m.match_id} href={`/chat/${m.match_id}`} className="list-item">
                <div className="avatar" style={img ? { backgroundImage: `url(${img})` } : undefined}>
                  {!img && <div style={{ display: 'grid', placeItems: 'center', height: '100%', fontSize: 24 }}>🐾</div>}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="row spread">
                    <strong>{m.other_pet_name}</strong>
                    <span className="muted" style={{ fontSize: 12 }}>{timeAgo(m.last_message_at ?? m.matched_at)}</span>
                  </div>
                  <div className="muted" style={{ fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {m.last_message ?? `Matched with ${m.other_owner_name} · say hi 👋`}
                  </div>
                </div>
              </Link>
            );
          })
        )}
      </div>
    </>
  );
}
