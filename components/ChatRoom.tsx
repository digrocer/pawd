'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { photoUrl, type MatchRow, type Message, type ReportReason } from '@/lib/types';

const REPORT_REASONS: { value: ReportReason; label: string }[] = [
  { value: 'fake_profile', label: 'Fake profile' },
  { value: 'welfare_concern', label: 'Animal welfare concern' },
  { value: 'harassment', label: 'Harassment' },
  { value: 'scam', label: 'Scam / pet sales' },
  { value: 'spam', label: 'Spam' },
];

export default function ChatRoom({
  matchId, me, match, initialMessages,
}: { matchId: string; me: string; match: MatchRow; initialMessages: Message[] }) {
  const supabase = createClient();
  const router = useRouter();
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [text, setText] = useState('');
  const [menu, setMenu] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [safetySeen, setSafetySeen] = useState(initialMessages.length > 0);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages]);

  useEffect(() => {
    const channel = supabase
      .channel(`chat:${matchId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages', filter: `match_id=eq.${matchId}` },
        (payload) => {
          const msg = payload.new as Message;
          setMessages((prev) => (prev.some((m) => m.id === msg.id) ? prev : [...prev, msg]));
        },
      )
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [supabase, matchId]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body) return;
    setText('');
    const optimistic: Message = {
      id: crypto.randomUUID(), match_id: matchId, sender_id: me, body, image_path: null,
      created_at: new Date().toISOString(),
    };
    setMessages((prev) => [...prev, optimistic]);
    const { data, error } = await supabase
      .from('messages')
      .insert({ match_id: matchId, sender_id: me, body })
      .select('*')
      .single();
    if (error) {
      setMessages((prev) => prev.filter((m) => m.id !== optimistic.id));
      alert(error.message);
      return;
    }
    setMessages((prev) => prev.map((m) => (m.id === optimistic.id ? (data as Message) : m)));
  }

  async function block() {
    if (!confirm(`Block ${match.other_owner_name}? This unmatches you and hides you from each other.`)) return;
    await supabase.rpc('block_owner', { p_blocked: match.other_owner });
    router.push('/matches');
    router.refresh();
  }

  async function submitReport(reason: ReportReason) {
    await supabase.from('reports').insert({
      reporter_id: me,
      target_owner: match.other_owner,
      target_pet: match.other_pet,
      reason,
    });
    setReporting(false);
    setMenu(false);
    alert('Thanks — our team reviews reports within 24h (2h for welfare & safety). You can also block this user.');
  }

  const img = photoUrl('pet-photos', match.other_primary_photo);

  return (
    <div className="chat-wrap">
      <div className="appbar">
        <div className="row" style={{ gap: 10 }}>
          <Link href="/matches" style={{ fontSize: 22 }}>‹</Link>
          <div className="avatar sm" style={img ? { backgroundImage: `url(${img})` } : undefined} />
          <div>
            <strong>{match.other_pet_name}</strong>
            <div className="muted" style={{ fontSize: 12 }}>with {match.other_owner_name}</div>
          </div>
        </div>
        <button className="btn btn-ghost" style={{ width: 'auto', padding: '8px 12px' }} onClick={() => setMenu(true)}>⋯</button>
      </div>

      {!safetySeen && (
        <div className="safety-banner">
          🛡️ <strong>Meet safely.</strong> Always meet in a public place for the first time, tell a friend where you&apos;re going,
          and never send money for a pet. Report anything that feels off.
        </div>
      )}

      <div className="chat-scroll" ref={scrollRef}>
        {messages.length === 0 && (
          <div className="empty" style={{ margin: 'auto' }}>
            <div className="big">👋</div>
            <p>Say hi to {match.other_owner_name} and {match.other_pet_name}!</p>
          </div>
        )}
        {messages.map((m) => (
          <div key={m.id} className={`bubble ${m.sender_id === me ? 'me' : 'them'}`}>
            {m.body}
          </div>
        ))}
      </div>

      <form className="chat-input" onSubmit={send}>
        <input
          value={text}
          onChange={(e) => { setText(e.target.value); setSafetySeen(true); }}
          placeholder="Message…"
          maxLength={2000}
        />
        <button className="btn btn-primary" disabled={!text.trim()}>Send</button>
      </form>

      {menu && (
        <div className="modal-overlay" onClick={() => setMenu(false)}>
          <div className="sheet" onClick={(e) => e.stopPropagation()}>
            {!reporting ? (
              <div className="stack">
                <h3 style={{ margin: 0 }}>{match.other_pet_name}</h3>
                <button className="btn btn-ghost" onClick={() => setReporting(true)}>🚩 Report</button>
                <button className="btn btn-danger" onClick={block}>🚫 Block & unmatch</button>
                <button className="btn btn-ghost" onClick={() => setMenu(false)}>Cancel</button>
              </div>
            ) : (
              <div className="stack">
                <h3 style={{ margin: 0 }}>Report — why?</h3>
                {REPORT_REASONS.map((r) => (
                  <button key={r.value} className="btn btn-ghost" onClick={() => submitReport(r.value)}>{r.label}</button>
                ))}
                <button className="btn btn-ghost" onClick={() => setReporting(false)}>Back</button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
