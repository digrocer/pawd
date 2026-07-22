import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import SwipeDeck from '@/components/SwipeDeck';
import type { Pet } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function DiscoverPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: pets } = await supabase
    .from('pets')
    .select('*')
    .eq('owner_id', user.id)
    .eq('is_active', true)
    .order('created_at', { ascending: true });

  if (!pets || pets.length === 0) redirect('/onboarding');

  return <SwipeDeck pets={pets as Pet[]} />;
}
