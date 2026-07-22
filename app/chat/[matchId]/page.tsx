import { redirect, notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import ChatRoom from '@/components/ChatRoom';
import type { MatchRow, Message } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function ChatPage({ params }: { params: Promise<{ matchId: string }> }) {
  const { matchId } = await params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: matchesData } = await supabase.rpc('my_matches');
  const match = ((matchesData as MatchRow[]) ?? []).find((m) => m.match_id === matchId);
  if (!match) notFound();

  const { data: messages } = await supabase
    .from('messages')
    .select('*')
    .eq('match_id', matchId)
    .order('created_at', { ascending: true });

  return (
    <ChatRoom
      matchId={matchId}
      me={user.id}
      match={match}
      initialMessages={(messages as Message[]) ?? []}
    />
  );
}
