import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { PURPOSE_LABELS, photoUrl, type Pet } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PetsPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: pets } = await supabase
    .from('pets')
    .select('*, pet_photos(storage_path, position)')
    .eq('owner_id', user.id)
    .order('created_at', { ascending: true });

  const list = (pets as (Pet & { pet_photos: { storage_path: string; position: number }[] })[]) ?? [];

  return (
    <>
      <div className="appbar">
        <h1>My Pets</h1>
        {list.length < 5 && (
          <Link href="/pets/new" className="btn btn-primary" style={{ width: 'auto', padding: '9px 14px' }}>+ Add</Link>
        )}
      </div>
      <div className="content">
        {list.length === 0 ? (
          <div className="empty">
            <div className="big">🐶</div>
            <h3>No pets yet</h3>
            <Link href="/pets/new" className="btn btn-primary" style={{ maxWidth: 220, margin: '12px auto 0' }}>Add your first pet</Link>
          </div>
        ) : (
          list.map((p) => {
            const cover = [...(p.pet_photos ?? [])].sort((a, b) => a.position - b.position)[0];
            const img = photoUrl('pet-photos', cover?.storage_path ?? null);
            return (
              <Link key={p.id} href={`/pets/${p.id}/edit`} className="list-item">
                <div className="avatar" style={img ? { backgroundImage: `url(${img})` } : undefined}>
                  {!img && <div style={{ display: 'grid', placeItems: 'center', height: '100%', fontSize: 24 }}>{p.species === 'dog' ? '🐕' : '🐈'}</div>}
                </div>
                <div style={{ flex: 1 }}>
                  <div className="row spread">
                    <strong>{p.name}</strong>
                    {!p.is_active && <span className="badge">Hidden</span>}
                  </div>
                  <div className="muted" style={{ fontSize: 13 }}>
                    {p.breed} · {p.purposes.filter((x) => x !== 'breeding').map((x) => PURPOSE_LABELS[x]).join(', ') || 'Breeding'}
                  </div>
                </div>
                <span className="muted" style={{ fontSize: 20 }}>›</span>
              </Link>
            );
          })
        )}
        {list.length >= 5 && <p className="muted center" style={{ fontSize: 13 }}>Free tier: up to 5 pets.</p>}
      </div>
    </>
  );
}
