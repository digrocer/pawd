-- PAWD — Row Level Security
-- Principle: owners.location (raw coords) is NEVER exposed to other users.
-- Public info about other owners/pets flows only through SECURITY DEFINER RPCs
-- that select curated columns (see 0002). Direct table reads are locked down.

alter table public.owners     enable row level security;
alter table public.pets       enable row level security;
alter table public.pet_photos enable row level security;
alter table public.swipes     enable row level security;
alter table public.matches    enable row level security;
alter table public.messages   enable row level security;
alter table public.reports    enable row level security;
alter table public.blocks     enable row level security;

-- Helper: is the current user a participant of a match?
create or replace function public.is_match_participant(p_match uuid)
  returns boolean language sql security definer stable set search_path = public as $$
  select exists(
    select 1 from public.matches m
    join public.pets pa on pa.id = m.pet_a
    join public.pets pb on pb.id = m.pet_b
    where m.id = p_match and (pa.owner_id = auth.uid() or pb.owner_id = auth.uid())
  );
$$;

-- ── owners ──────────────────────────────────────────────────
drop policy if exists owners_select_own on public.owners;
create policy owners_select_own on public.owners
  for select using (id = auth.uid());
drop policy if exists owners_update_own on public.owners;
create policy owners_update_own on public.owners
  for update using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists owners_insert_own on public.owners;
create policy owners_insert_own on public.owners
  for insert with check (id = auth.uid());

-- ── pets ────────────────────────────────────────────────────
-- Own pets: full access. Other pets: readable if active, owner not banned,
-- and no block between the two owners. (Pet rows carry no location.)
drop policy if exists pets_select on public.pets;
create policy pets_select on public.pets
  for select using (
    owner_id = auth.uid()
    or (
      is_active
      and not exists (select 1 from public.owners o where o.id = pets.owner_id and o.is_banned)
      and not exists (select 1 from public.blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = pets.owner_id)
           or (b.blocker_id = pets.owner_id and b.blocked_id = auth.uid()))
    )
  );
drop policy if exists pets_write_own on public.pets;
create policy pets_write_own on public.pets
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ── pet_photos ──────────────────────────────────────────────
drop policy if exists pet_photos_select on public.pet_photos;
create policy pet_photos_select on public.pet_photos
  for select using (
    exists (select 1 from public.pets p where p.id = pet_photos.pet_id
      and (p.owner_id = auth.uid() or (pet_photos.approved and p.is_active)))
  );
drop policy if exists pet_photos_write_own on public.pet_photos;
create policy pet_photos_write_own on public.pet_photos
  for all using (
    exists (select 1 from public.pets p where p.id = pet_photos.pet_id and p.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.pets p where p.id = pet_photos.pet_id and p.owner_id = auth.uid())
  );

-- ── swipes ──────────────────────────────────────────────────
drop policy if exists swipes_select_own on public.swipes;
create policy swipes_select_own on public.swipes
  for select using (
    exists (select 1 from public.pets p where p.id = swipes.swiper_pet and p.owner_id = auth.uid())
  );
drop policy if exists swipes_insert_own on public.swipes;
create policy swipes_insert_own on public.swipes
  for insert with check (
    exists (select 1 from public.pets p where p.id = swipes.swiper_pet and p.owner_id = auth.uid())
  );

-- ── matches ─────────────────────────────────────────────────
drop policy if exists matches_select_participant on public.matches;
create policy matches_select_participant on public.matches
  for select using (
    exists (select 1 from public.pets p where p.id = matches.pet_a and p.owner_id = auth.uid())
    or exists (select 1 from public.pets p where p.id = matches.pet_b and p.owner_id = auth.uid())
  );

-- ── messages ────────────────────────────────────────────────
drop policy if exists messages_select_participant on public.messages;
create policy messages_select_participant on public.messages
  for select using (public.is_match_participant(match_id));
drop policy if exists messages_insert_participant on public.messages;
create policy messages_insert_participant on public.messages
  for insert with check (
    sender_id = auth.uid()
    and public.is_match_participant(match_id)
    and exists (select 1 from public.matches m where m.id = match_id and m.is_active)
  );

-- ── reports ─────────────────────────────────────────────────
drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
  for insert with check (reporter_id = auth.uid());
drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select using (reporter_id = auth.uid());

-- ── blocks ──────────────────────────────────────────────────
drop policy if exists blocks_all_own on public.blocks;
create policy blocks_all_own on public.blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ── Grants for RPCs (authenticated role) ────────────────────
grant execute on function public.record_swipe(uuid, uuid, swipe_dir, int) to authenticated;
grant execute on function public.discovery_deck(uuid, numeric, species, pet_sex, int, int, boolean, int) to authenticated;
grant execute on function public.set_my_location(double precision, double precision) to authenticated;
grant execute on function public.my_matches() to authenticated;
grant execute on function public.block_owner(uuid) to authenticated;
grant execute on function public.is_match_participant(uuid) to authenticated;
