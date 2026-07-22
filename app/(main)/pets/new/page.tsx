'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import PetForm from '@/components/PetForm';

export default function NewPet() {
  const supabase = createClient();
  const router = useRouter();
  const [ownerId, setOwnerId] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) router.push('/login');
      else setOwnerId(data.user.id);
    });
  }, [router, supabase]);

  if (!ownerId) return <div className="spinner" />;

  return (
    <>
      <div className="appbar">
        <h1><button onClick={() => router.back()} style={{ background: 'none', border: 'none', fontSize: 22, color: 'inherit' }}>‹</button> New pet</h1>
      </div>
      <div className="content">
        <PetForm ownerId={ownerId} onSaved={() => { router.push('/pets'); router.refresh(); }} />
      </div>
    </>
  );
}
