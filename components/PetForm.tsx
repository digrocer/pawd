'use client';

import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import {
  PURPOSE_LABELS,
  VACC_LABELS,
  type Pet,
  type PurposeFlag,
  type Species,
  type PetSex,
  type VaccStatus,
  photoUrl,
} from '@/lib/types';

const TEMPERAMENTS = ['Friendly', 'Shy', 'Playful', 'Calm', 'Energetic', 'Protective', 'Curious', 'Gentle'];

interface Props {
  ownerId: string;
  existing?: Pet & { photos?: { id: string; storage_path: string; position: number }[] };
  onSaved: (petId: string) => void;
}

export default function PetForm({ ownerId, existing, onSaved }: Props) {
  const supabase = createClient();
  const [name, setName] = useState(existing?.name ?? '');
  const [species, setSpecies] = useState<Species>(existing?.species ?? 'dog');
  const [breed, setBreed] = useState(existing?.breed ?? 'Mixed/Unknown');
  const [sex, setSex] = useState<PetSex>(existing?.sex ?? 'male');
  const [dob, setDob] = useState(existing?.date_of_birth ?? '');
  const [neutered, setNeutered] = useState<boolean | null>(existing?.neutered ?? null);
  const [vaccination, setVaccination] = useState<VaccStatus>(existing?.vaccination ?? 'unknown');
  const [energy, setEnergy] = useState(existing?.energy_level ?? 3);
  const [bio, setBio] = useState(existing?.bio ?? '');
  const [temperament, setTemperament] = useState<string[]>(existing?.temperament ?? []);
  const [purposes, setPurposes] = useState<PurposeFlag[]>(existing?.purposes ?? ['playdates']);

  const [existingPhotos, setExistingPhotos] = useState(existing?.photos ?? []);
  const [newFiles, setNewFiles] = useState<File[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const totalPhotos = existingPhotos.length + newFiles.length;

  function toggle<T>(arr: T[], v: T, setter: (a: T[]) => void, max = 99) {
    if (arr.includes(v)) setter(arr.filter((x) => x !== v));
    else if (arr.length < max) setter([...arr, v]);
  }

  function addFiles(files: FileList | null) {
    if (!files) return;
    const room = 6 - totalPhotos;
    setNewFiles([...newFiles, ...Array.from(files).slice(0, room)]);
  }

  async function removeExisting(id: string, path: string) {
    setExistingPhotos(existingPhotos.filter((p) => p.id !== id));
    await supabase.from('pet_photos').delete().eq('id', id);
    await supabase.storage.from('pet-photos').remove([path]);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (purposes.length === 0) return setError('Pick at least one purpose.');
    if (totalPhotos === 0) return setError('Add at least one photo.');
    setLoading(true);

    const payload = {
      owner_id: ownerId,
      name: name.trim(),
      species,
      breed: breed.trim() || 'Mixed/Unknown',
      sex,
      date_of_birth: dob || null,
      neutered,
      vaccination,
      energy_level: energy,
      bio: bio.trim() || null,
      temperament: temperament.slice(0, 5),
      purposes,
    };

    let petId = existing?.id;
    if (existing) {
      const { error } = await supabase.from('pets').update(payload).eq('id', existing.id);
      if (error) { setLoading(false); return setError(error.message); }
    } else {
      const { data, error } = await supabase.from('pets').insert(payload).select('id').single();
      if (error || !data) { setLoading(false); return setError(error?.message ?? 'Could not save pet.'); }
      petId = data.id;
    }

    // Upload new photos
    let position = existingPhotos.length;
    for (const file of newFiles) {
      const ext = file.name.split('.').pop() || 'jpg';
      const path = `${ownerId}/${petId}/${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage.from('pet-photos').upload(path, file, {
        upsert: false,
        contentType: file.type,
      });
      if (upErr) { setLoading(false); return setError(`Photo upload failed: ${upErr.message}`); }
      const { error: rowErr } = await supabase.from('pet_photos').insert({
        pet_id: petId, storage_path: path, position: position++, approved: true,
      });
      if (rowErr) { setLoading(false); return setError(rowErr.message); }
    }

    setLoading(false);
    onSaved(petId!);
  }

  return (
    <form onSubmit={submit} className="stack">
      {error && <div className="error-banner">{error}</div>}

      <label>Photos ({totalPhotos}/6) — first is the cover</label>
      <div className="photo-grid">
        {existingPhotos.map((p) => (
          <div key={p.id} className="photo-slot" style={{ backgroundImage: `url(${photoUrl('pet-photos', p.storage_path)})` }}>
            <button type="button" className="rm" onClick={() => removeExisting(p.id, p.storage_path)}>×</button>
          </div>
        ))}
        {newFiles.map((f, i) => (
          <div key={i} className="photo-slot" style={{ backgroundImage: `url(${URL.createObjectURL(f)})` }}>
            <button type="button" className="rm" onClick={() => setNewFiles(newFiles.filter((_, j) => j !== i))}>×</button>
          </div>
        ))}
        {totalPhotos < 6 && (
          <label className="photo-slot" style={{ cursor: 'pointer' }}>
            +
            <input type="file" accept="image/*" multiple hidden onChange={(e) => addFiles(e.target.files)} />
          </label>
        )}
      </div>

      <div>
        <label htmlFor="name">Name</label>
        <input id="name" value={name} onChange={(e) => setName(e.target.value)} maxLength={60} required />
      </div>

      <label>Species</label>
      <div className="seg">
        {(['dog', 'cat'] as Species[]).map((s) => (
          <button type="button" key={s} className={`chip ${species === s ? 'on' : ''}`} onClick={() => setSpecies(s)}>
            {s === 'dog' ? '🐕 Dog' : '🐈 Cat'}
          </button>
        ))}
      </div>

      <div>
        <label htmlFor="breed">Breed</label>
        <input id="breed" value={breed} onChange={(e) => setBreed(e.target.value)} placeholder="e.g. Golden Retriever, Mixed/Unknown" />
      </div>

      <label>Sex</label>
      <div className="seg">
        {(['male', 'female'] as PetSex[]).map((s) => (
          <button type="button" key={s} className={`chip ${sex === s ? 'on' : ''}`} onClick={() => setSex(s)}>
            {s === 'male' ? '♂ Male' : '♀ Female'}
          </button>
        ))}
      </div>

      <div>
        <label htmlFor="dob">Date of birth</label>
        <input id="dob" type="date" value={dob ?? ''} max={new Date().toISOString().slice(0, 10)} onChange={(e) => setDob(e.target.value)} />
      </div>

      <label>Neutered / spayed</label>
      <div className="seg">
        {[['Yes', true], ['No', false], ['Unsure', null]].map(([lbl, val]) => (
          <button type="button" key={String(lbl)} className={`chip ${neutered === val ? 'on' : ''}`} onClick={() => setNeutered(val as boolean | null)}>
            {lbl as string}
          </button>
        ))}
      </div>

      <label>Vaccination (self-declared)</label>
      <div className="seg">
        {(Object.keys(VACC_LABELS) as VaccStatus[]).map((v) => (
          <button type="button" key={v} className={`chip ${vaccination === v ? 'on' : ''}`} onClick={() => setVaccination(v)}>
            {VACC_LABELS[v]}
          </button>
        ))}
      </div>

      <label htmlFor="energy">Energy level: {energy}/5</label>
      <input id="energy" type="range" min={1} max={5} value={energy} onChange={(e) => setEnergy(Number(e.target.value))} />

      <label>Temperament (max 5)</label>
      <div className="chips">
        {TEMPERAMENTS.map((t) => (
          <button type="button" key={t} className={`chip ${temperament.includes(t) ? 'on' : ''}`} onClick={() => toggle(temperament, t, setTemperament, 5)}>
            {t}
          </button>
        ))}
      </div>

      <label>Looking for</label>
      <div className="chips">
        {(Object.keys(PURPOSE_LABELS) as PurposeFlag[]).map((p) => (
          <button
            type="button"
            key={p}
            disabled={p === 'breeding'}
            title={p === 'breeding' ? 'Breeding matching unlocks in v1.1 (needs verification)' : undefined}
            className={`chip ${purposes.includes(p) ? 'on' : ''}`}
            style={p === 'breeding' ? { opacity: 0.45 } : undefined}
            onClick={() => toggle(purposes, p, setPurposes)}
          >
            {PURPOSE_LABELS[p]}{p === 'breeding' ? ' 🔒' : ''}
          </button>
        ))}
      </div>

      <div>
        <label htmlFor="bio">Short bio ({bio.length}/280)</label>
        <textarea id="bio" value={bio} maxLength={280} onChange={(e) => setBio(e.target.value)} placeholder="Loves fetch, hates the vacuum…" />
      </div>

      <button className="btn btn-primary" disabled={loading}>
        {loading ? 'Saving…' : existing ? 'Save changes' : 'Create pet profile'}
      </button>
    </form>
  );
}
