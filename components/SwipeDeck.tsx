'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import {
  PURPOSE_LABELS,
  photoUrl,
  type DeckCard,
  type Pet,
  type Species,
  type PetSex,
} from '@/lib/types';

interface Filters {
  radius: number;
  species: Species | '';
  sex: PetSex | '';
  vaccinatedOnly: boolean;
}

export default function SwipeDeck({ pets }: { pets: Pet[] }) {
  const supabase = createClient();
  const [activePet, setActivePet] = useState<Pet>(pets[0]);
  const [deck, setDeck] = useState<DeckCard[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<Filters>({ radius: 25, species: '', sex: '', vaccinatedOnly: false });
  const [matchWith, setMatchWith] = useState<DeckCard | null>(null);
  const [limitHit, setLimitHit] = useState(false);

  const loadDeck = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error } = await supabase.rpc('discovery_deck', {
      p_viewer_pet: activePet.id,
      p_radius_km: filters.radius,
      p_species: filters.species || null,
      p_sex: filters.sex || null,
      p_vaccinated_only: filters.vaccinatedOnly,
      p_limit: 30,
    });
    setLoading(false);
    if (error) return setError(error.message);
    setDeck((data as DeckCard[]) ?? []);
  }, [supabase, activePet.id, filters]);

  useEffect(() => { loadDeck(); }, [loadDeck]);

  async function act(target: DeckCard, direction: 'like' | 'pass') {
    setDeck((d) => d.filter((c) => c.pet_id !== target.pet_id));
    if (direction === 'pass') {
      await supabase.rpc('record_swipe', { p_swiper_pet: activePet.id, p_target_pet: target.pet_id, p_direction: 'pass' });
      return;
    }
    const { data, error } = await supabase.rpc('record_swipe', {
      p_swiper_pet: activePet.id, p_target_pet: target.pet_id, p_direction: 'like',
    });
    if (error) { setError(error.message); return; }
    const res = data as { ok: boolean; matched?: boolean; error?: string };
    if (!res.ok && res.error === 'daily_like_limit') { setLimitHit(true); return; }
    if (res.matched) setMatchWith(target);
  }

  const top = deck[deck.length - 1];

  return (
    <>
      <div className="appbar">
        <h1><span className="brand-mark">PAWD</span></h1>
        <div className="row" style={{ gap: 8 }}>
          {pets.length > 1 && (
            <select
              value={activePet.id}
              onChange={(e) => setActivePet(pets.find((p) => p.id === e.target.value)!)}
              style={{ width: 'auto', padding: '8px 10px', fontSize: 14 }}
            >
              {pets.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          )}
          <button className="btn btn-ghost" style={{ width: 'auto', padding: '9px 12px' }} onClick={() => setShowFilters(true)}>
            ⚙︎ Filters
          </button>
        </div>
      </div>

      <div className="content">
        {activePet.purposes.every((p) => p === 'breeding') && (
          <div className="notice" style={{ marginBottom: 12 }}>
            {activePet.name} is set to breeding-only. Breeding discovery unlocks in v1.1 — add a social purpose to appear in decks.
          </div>
        )}

        {error && <div className="error-banner" style={{ marginBottom: 12 }}>{error}</div>}

        {loading ? (
          <div className="spinner" />
        ) : deck.length === 0 ? (
          <div className="empty">
            <div className="big">🐾</div>
            <h3>No more pets nearby</h3>
            <p>Try widening your distance filter, or check back soon — PAWD grows neighbourhood by neighbourhood.</p>
            <button className="btn btn-ghost" onClick={loadDeck} style={{ maxWidth: 220, margin: '12px auto 0' }}>Refresh</button>
          </div>
        ) : (
          <>
            <div className="deck">
              {deck.slice(-3).map((card, i, arr) => {
                const isTop = i === arr.length - 1;
                return (
                  <Card
                    key={card.pet_id}
                    card={card}
                    isTop={isTop}
                    depth={arr.length - 1 - i}
                    onSwipe={(dir) => act(card, dir)}
                  />
                );
              })}
            </div>
            <div className="deck-actions">
              <button className="round-btn pass" aria-label="Pass" onClick={() => top && act(top, 'pass')}>✕</button>
              <button className="round-btn like big" aria-label="Like" onClick={() => top && act(top, 'like')}>♥</button>
            </div>
          </>
        )}
      </div>

      {showFilters && (
        <FilterSheet
          filters={filters}
          onClose={() => setShowFilters(false)}
          onApply={(f) => { setFilters(f); setShowFilters(false); }}
        />
      )}

      {matchWith && (
        <MatchModal card={matchWith} onClose={() => setMatchWith(null)} />
      )}

      {limitHit && (
        <div className="modal-overlay" onClick={() => setLimitHit(false)}>
          <div className="card" style={{ padding: 24, maxWidth: 340, textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
            <div style={{ fontSize: 40 }}>⏳</div>
            <h3>Daily likes reached</h3>
            <p className="muted">You&apos;ve used all 25 likes for today. Come back tomorrow — or keep passing to line up tomorrow&apos;s picks.</p>
            <button className="btn btn-primary" onClick={() => setLimitHit(false)}>Got it</button>
          </div>
        </div>
      )}
    </>
  );
}

function Card({
  card, isTop, depth, onSwipe,
}: { card: DeckCard; isTop: boolean; depth: number; onSwipe: (d: 'like' | 'pass') => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const start = useRef<{ x: number; y: number } | null>(null);
  const [dragging, setDragging] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || !isTop) return;

    function onDown(e: PointerEvent) {
      start.current = { x: e.clientX, y: e.clientY };
      setDragging(true);
      el!.setPointerCapture(e.pointerId);
    }
    function onMove(e: PointerEvent) {
      if (!start.current) return;
      const dx = e.clientX - start.current.x;
      const dy = e.clientY - start.current.y;
      const rot = dx / 18;
      el!.style.transform = `translate(${dx}px, ${dy}px) rotate(${rot}deg)`;
      const like = el!.querySelector('.stamp.like') as HTMLElement;
      const nope = el!.querySelector('.stamp.nope') as HTMLElement;
      if (like) like.style.opacity = String(Math.max(0, Math.min(1, dx / 90)));
      if (nope) nope.style.opacity = String(Math.max(0, Math.min(1, -dx / 90)));
    }
    function onUp(e: PointerEvent) {
      if (!start.current) return;
      const dx = e.clientX - start.current.x;
      start.current = null;
      setDragging(false);
      const threshold = 100;
      if (Math.abs(dx) > threshold) {
        const dir = dx > 0 ? 'like' : 'pass';
        el!.style.transition = 'transform 0.3s ease';
        el!.style.transform = `translate(${dx > 0 ? 700 : -700}px, 0) rotate(${dx > 0 ? 30 : -30}deg)`;
        setTimeout(() => onSwipe(dir), 180);
      } else {
        el!.style.transition = 'transform 0.25s ease';
        el!.style.transform = '';
        const like = el!.querySelector('.stamp.like') as HTMLElement;
        const nope = el!.querySelector('.stamp.nope') as HTMLElement;
        if (like) like.style.opacity = '0';
        if (nope) nope.style.opacity = '0';
        setTimeout(() => { if (el) el.style.transition = ''; }, 250);
      }
    }
    el.addEventListener('pointerdown', onDown);
    el.addEventListener('pointermove', onMove);
    el.addEventListener('pointerup', onUp);
    return () => {
      el.removeEventListener('pointerdown', onDown);
      el.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerup', onUp);
    };
  }, [isTop, onSwipe]);

  const img = photoUrl('pet-photos', card.primary_photo);
  const ageLabel = card.age_months != null
    ? card.age_months >= 12 ? `${Math.floor(card.age_months / 12)}y` : `${card.age_months}mo`
    : null;

  return (
    <div
      ref={ref}
      className="swipe-card"
      style={{
        zIndex: 10 - depth,
        transform: !dragging ? `scale(${1 - depth * 0.04}) translateY(${depth * 10}px)` : undefined,
        pointerEvents: isTop ? 'auto' : 'none',
      }}
    >
      <div className="photo" style={img ? { backgroundImage: `url(${img})` } : undefined}>
        {!img && <div style={{ display: 'grid', placeItems: 'center', height: '100%', fontSize: 64 }}>{card.species === 'dog' ? '🐕' : '🐈'}</div>}
      </div>
      <div className="scrim" />
      <div className="stamp like">LIKE</div>
      <div className="stamp nope">NOPE</div>
      <div className="info">
        <h2>{card.name}{ageLabel ? <span style={{ fontWeight: 400 }}> · {ageLabel}</span> : null}</h2>
        <div className="sub">
          {card.breed} · {card.sex === 'male' ? '♂' : '♀'} · {card.distance_km} km away
        </div>
        {card.bio && <div className="sub" style={{ marginTop: 6, opacity: 0.85 }}>{card.bio}</div>}
        <div className="tags">
          {card.purposes.filter((p) => p !== 'breeding').map((p) => <span key={p} className="chip">{PURPOSE_LABELS[p]}</span>)}
          {card.temperament.slice(0, 2).map((t) => <span key={t} className="chip">{t}</span>)}
        </div>
      </div>
    </div>
  );
}

function FilterSheet({ filters, onApply, onClose }: { filters: Filters; onApply: (f: Filters) => void; onClose: () => void }) {
  const [f, setF] = useState(filters);
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <div className="row spread" style={{ marginBottom: 8 }}>
          <h3 style={{ margin: 0 }}>Filters</h3>
          <button className="btn btn-ghost" style={{ width: 'auto', padding: '6px 12px' }} onClick={onClose}>Close</button>
        </div>
        <label>Distance: {f.radius} km</label>
        <input type="range" min={1} max={50} value={f.radius} onChange={(e) => setF({ ...f, radius: Number(e.target.value) })} />
        <label>Species</label>
        <div className="seg">
          {[['Any', ''], ['Dog', 'dog'], ['Cat', 'cat']].map(([lbl, val]) => (
            <button key={lbl} className={`chip ${f.species === val ? 'on' : ''}`} onClick={() => setF({ ...f, species: val as Species | '' })}>{lbl}</button>
          ))}
        </div>
        <label>Sex</label>
        <div className="seg">
          {[['Any', ''], ['Male', 'male'], ['Female', 'female']].map(([lbl, val]) => (
            <button key={lbl} className={`chip ${f.sex === val ? 'on' : ''}`} onClick={() => setF({ ...f, sex: val as PetSex | '' })}>{lbl}</button>
          ))}
        </div>
        <label>Vaccination</label>
        <div className="seg">
          <button className={`chip ${!f.vaccinatedOnly ? 'on' : ''}`} onClick={() => setF({ ...f, vaccinatedOnly: false })}>Any</button>
          <button className={`chip ${f.vaccinatedOnly ? 'on' : ''}`} onClick={() => setF({ ...f, vaccinatedOnly: true })}>Vaccinated only</button>
        </div>
        <button className="btn btn-primary" style={{ marginTop: 18 }} onClick={() => onApply(f)}>Apply filters</button>
      </div>
    </div>
  );
}

function MatchModal({ card, onClose }: { card: DeckCard; onClose: () => void }) {
  const img = photoUrl('pet-photos', card.primary_photo);
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="card" style={{ padding: 28, maxWidth: 340, textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
        <div style={{ fontSize: 46 }}>🎉</div>
        <h2 style={{ margin: '6px 0' }}>It&apos;s a match!</h2>
        <p className="muted">You and {card.name} liked each other.</p>
        <div className="avatar" style={{ width: 96, height: 96, margin: '12px auto', backgroundImage: img ? `url(${img})` : undefined }} />
        <div className="stack">
          <Link href="/matches" className="btn btn-primary" onClick={onClose}>Say hi 👋</Link>
          <button className="btn btn-ghost" onClick={onClose}>Keep swiping</button>
        </div>
      </div>
    </div>
  );
}
