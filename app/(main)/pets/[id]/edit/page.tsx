'use client';

import { use, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import PetForm from '@/components/PetForm';
import type { Pet } from '@/lib/types';

type PetWithPhotos = Pet & { photos: { id: string; storage_path: string; position: number }[] };

export default function EditPet({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const supabase = createClient();
  const router = useRouter();
  const [ownerId, setOwnerId] = useState<string | null>(null);
  const [pet, setPet] = useState<PetWithPhotos | null>(null);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { router.push('/login'); return; }
      setOwnerId(user.id);
      const { data } = await supabase
        .from('pets')
        .select('*, pet_photos(id, storage_path, position)')
        .eq('id', id)
        .eq('owner_id', user.id)
        .single();
      if (!data) { setNotFound(true); return; }
      const { pet_photos, ...rest } = data as Pet & { pet_photos: PetWithPhotos['photos'] };
      setPet({ ...(rest as Pet), photos: [...(pet_photos ?? [])].sort((a, b) => a.position - b.position) });
    })();
  }, [id, router, supabase]);

  async function toggleActive() {
    if (!pet) return;
    await supabase.from('pets').update({ is_active: !pet.is_active }).eq('id', pet.id);
    setPet({ ...pet, is_active: !pet.is_active });
  }

  async function deletePet() {
    if (!pet) return;
    if (!confirm(`Delete ${pet.name}'s profile permanently? This removes all matches and chats for this pet.`)) return;
    await supabase.from('pets').delete().eq('id', pet.id);
    router.push('/pets');
    router.refresh();
  }

  if (notFound) return <div className="content"><div className="empty"><div className="big">🤔</div><p>Pet not found.</p></div></div>;
  if (!ownerId || !pet) return <div className="spinner" />;

  return (
    <>
      <div className="appbar">
        <h1><button onClick={() => router.back()} style={{ background: 'none', border: 'none', fontSize: 22, color: 'inherit' }}>‹</button> Edit {pet.name}</h1>
      </div>
      <div className="content">
        <PetForm ownerId={ownerId} existing={pet} onSaved={() => { router.push('/pets'); router.refresh(); }} />
        <div className="stack" style={{ marginTop: 20 }}>
          <button className="btn btn-ghost" onClick={toggleActive}>
            {pet.is_active ? '🙈 Hide from discovery' : '👀 Show in discovery'}
          </button>
          <button className="btn btn-danger" onClick={deletePet}>Delete pet</button>
        </div>
      </div>
    </>
  );
}
