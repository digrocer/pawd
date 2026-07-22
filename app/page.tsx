import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { count } = await supabase
    .from('pets')
    .select('id', { count: 'exact', head: true })
    .eq('owner_id', user.id);

  if (!count || count === 0) redirect('/onboarding');
  redirect('/discover');
}
