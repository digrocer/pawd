-- PAWD — Matching engine + discovery RPC + safety helpers

-- ─────────────────────────────────────────────────────────────
-- Match detection: on a mutual 'like', create exactly one match.
-- Canonical (pet_a < pet_b) + unique constraint make this race-safe
-- (FR-11 / pre-launch test #1: two simultaneous likes → one match).
-- ─────────────────────────────────────────────────────────────
create or replace function public.detect_match() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  reciprocal boolean;
  a uuid; b uuid;
begin
  if new.direction <> 'like' then return new; end if;

  select exists(
    select 1 from public.swipes s
    where s.swiper_pet = new.target_pet
      and s.target_pet = new.swiper_pet
      and s.direction = 'like'
  ) into reciprocal;

  if reciprocal then
    a := least(new.swiper_pet, new.target_pet);
    b := greatest(new.swiper_pet, new.target_pet);
    insert into public.matches (pet_a, pet_b) values (a, b)
      on conflict (pet_a, pet_b) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists trg_detect_match on public.swipes;
create trigger trg_detect_match after insert on public.swipes
  for each row execute function public.detect_match();

-- ─────────────────────────────────────────────────────────────
-- record_swipe: RPC clients call. Validates ownership, records swipe,
-- returns whether it produced a match. Enforces daily like limit (FR-13).
-- ─────────────────────────────────────────────────────────────
create or replace function public.record_swipe(
  p_swiper_pet uuid,
  p_target_pet uuid,
  p_direction  swipe_dir,
  p_daily_like_limit int default 25
) returns jsonb
  language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_likes_today int;
  v_matched boolean := false;
  a uuid; b uuid;
begin
  -- Ownership check
  if not exists (select 1 from public.pets where id = p_swiper_pet and owner_id = v_owner) then
    raise exception 'Not your pet';
  end if;

  -- Daily like limit (free tier)
  if p_direction = 'like' then
    select count(*) into v_likes_today
    from public.swipes
    where swiper_pet = p_swiper_pet
      and direction = 'like'
      and created_at >= date_trunc('day', now());
    if v_likes_today >= p_daily_like_limit then
      return jsonb_build_object('ok', false, 'error', 'daily_like_limit', 'limit', p_daily_like_limit);
    end if;
  end if;

  insert into public.swipes (swiper_pet, target_pet, direction)
  values (p_swiper_pet, p_target_pet, p_direction)
  on conflict (swiper_pet, target_pet) do update set direction = excluded.direction;

  a := least(p_swiper_pet, p_target_pet);
  b := greatest(p_swiper_pet, p_target_pet);
  select exists(select 1 from public.matches where pet_a = a and pet_b = b) into v_matched;

  return jsonb_build_object('ok', true, 'matched', v_matched);
end $$;

-- ─────────────────────────────────────────────────────────────
-- discovery_deck: nearby candidate pets for a given viewer pet.
-- Rules enforced:
--   • same-purpose overlap is a HARD rule (FR-14)
--   • exclude self, already-swiped, blocked (either direction), banned owners
--   • PostGIS ST_DWithin distance filter, sorted by score
--   • RETURNS ROUNDED DISTANCE ONLY — never raw coordinates (privacy NFR)
-- ─────────────────────────────────────────────────────────────
create or replace function public.discovery_deck(
  p_viewer_pet uuid,
  p_radius_km  numeric default 25,
  p_species    species default null,
  p_sex        pet_sex default null,
  p_min_age_months int default null,
  p_max_age_months int default null,
  p_vaccinated_only boolean default false,
  p_limit      int default 30
) returns table (
  pet_id uuid,
  name text,
  species species,
  breed text,
  sex pet_sex,
  age_months int,
  energy_level int,
  temperament text[],
  bio text,
  purposes purpose_flag[],
  vaccination vacc_status,
  owner_display_name text,
  distance_km numeric,
  primary_photo text
)
  language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_loc geography;
  v_purposes purpose_flag[];
begin
  -- Must own the viewer pet
  select o.location, p.purposes into v_loc, v_purposes
  from public.pets p join public.owners o on o.id = p.owner_id
  where p.id = p_viewer_pet and p.owner_id = v_owner;
  if not found then raise exception 'Not your pet'; end if;

  return query
  select
    p.id,
    p.name,
    p.species,
    p.breed,
    p.sex,
    case when p.date_of_birth is not null
      then (extract(year from age(p.date_of_birth))*12 + extract(month from age(p.date_of_birth)))::int
      else null end as age_months,
    p.energy_level,
    p.temperament,
    p.bio,
    p.purposes,
    p.vaccination,
    o.display_name,
    -- Location privacy: round to 0.1 km, floor at 1 km (NFR privacy)
    greatest(1.0, round((st_distance(o.location, v_loc) / 1000.0)::numeric, 1)) as distance_km,
    (select pp.storage_path from public.pet_photos pp
       where pp.pet_id = p.id and pp.approved order by pp.position limit 1) as primary_photo
  from public.pets p
  join public.owners o on o.id = p.owner_id
  where p.id <> p_viewer_pet
    and p.owner_id <> v_owner
    and p.is_active
    and not o.is_banned
    and o.location is not null
    and v_loc is not null
    -- HARD purpose separation (FR-14): must share ≥1 purpose
    and p.purposes && v_purposes
    -- Breeding is discovery-gated until v1.1: exclude breeding-only overlaps
    and (p.purposes && (array['playdates','walking','friends']::purpose_flag[]))
    -- geo radius
    and st_dwithin(o.location, v_loc, p_radius_km * 1000)
    -- optional filters
    and (p_species is null or p.species = p_species)
    and (p_sex is null or p.sex = p_sex)
    and (not p_vaccinated_only or p.vaccination = 'up_to_date')
    and (p_min_age_months is null or p.date_of_birth is null or
         (extract(year from age(p.date_of_birth))*12 + extract(month from age(p.date_of_birth))) >= p_min_age_months)
    and (p_max_age_months is null or p.date_of_birth is null or
         (extract(year from age(p.date_of_birth))*12 + extract(month from age(p.date_of_birth))) <= p_max_age_months)
    -- exclude already swiped
    and not exists (select 1 from public.swipes s where s.swiper_pet = p_viewer_pet and s.target_pet = p.id)
    -- exclude blocks either direction
    and not exists (select 1 from public.blocks b
        where (b.blocker_id = v_owner and b.blocked_id = o.id)
           or (b.blocker_id = o.id and b.blocked_id = v_owner))
  order by
    -- score: closer + purpose overlap count + recent activity
    (st_distance(o.location, v_loc)) asc,
    (select count(*) from (select unnest(p.purposes) intersect select unnest(v_purposes)) _ov) desc,
    p.updated_at desc
  limit p_limit;
end $$;

-- ─────────────────────────────────────────────────────────────
-- set_my_location: clients set their own location (raw coords stay server-side)
-- ─────────────────────────────────────────────────────────────
create or replace function public.set_my_location(p_lat double precision, p_lng double precision)
  returns void language plpgsql security definer set search_path = public as $$
begin
  update public.owners
  set location = st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      location_updated_at = now()
  where id = auth.uid();
end $$;

-- ─────────────────────────────────────────────────────────────
-- my_matches: match list with the *other* pet + owner for the current user.
-- ─────────────────────────────────────────────────────────────
create or replace function public.my_matches()
  returns table (
    match_id uuid,
    matched_at timestamptz,
    my_pet uuid,
    other_pet uuid,
    other_pet_name text,
    other_owner uuid,
    other_owner_name text,
    other_primary_photo text,
    last_message text,
    last_message_at timestamptz
  )
  language plpgsql security definer set search_path = public as $$
declare v_owner uuid := auth.uid();
begin
  return query
  select
    m.id, m.created_at,
    mine.id, theirs.id, theirs.name,
    theirs.owner_id, o.display_name,
    (select pp.storage_path from public.pet_photos pp where pp.pet_id = theirs.id and pp.approved order by pp.position limit 1),
    (select msg.body from public.messages msg where msg.match_id = m.id order by msg.created_at desc limit 1),
    (select msg.created_at from public.messages msg where msg.match_id = m.id order by msg.created_at desc limit 1)
  from public.matches m
  join public.pets pa on pa.id = m.pet_a
  join public.pets pb on pb.id = m.pet_b
  join lateral (select case when pa.owner_id = v_owner then pa else pb end) as mine_t(x) on true
  join public.pets mine on mine.id = (case when pa.owner_id = v_owner then pa.id else pb.id end)
  join public.pets theirs on theirs.id = (case when pa.owner_id = v_owner then pb.id else pa.id end)
  join public.owners o on o.id = theirs.owner_id
  where m.is_active
    and (pa.owner_id = v_owner or pb.owner_id = v_owner)
    and not exists (select 1 from public.blocks b
        where (b.blocker_id = v_owner and b.blocked_id = theirs.owner_id)
           or (b.blocker_id = theirs.owner_id and b.blocked_id = v_owner))
  order by coalesce(
    (select max(msg.created_at) from public.messages msg where msg.match_id = m.id), m.created_at) desc;
end $$;

-- ─────────────────────────────────────────────────────────────
-- block_owner: block + dissolve any matches between the two owners
-- ─────────────────────────────────────────────────────────────
create or replace function public.block_owner(p_blocked uuid)
  returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid := auth.uid();
begin
  if p_blocked = v_owner then raise exception 'Cannot block yourself'; end if;
  insert into public.blocks (blocker_id, blocked_id) values (v_owner, p_blocked)
    on conflict do nothing;
  update public.matches m set is_active = false
  from public.pets pa, public.pets pb
  where m.pet_a = pa.id and m.pet_b = pb.id
    and ((pa.owner_id = v_owner and pb.owner_id = p_blocked)
      or (pa.owner_id = p_blocked and pb.owner_id = v_owner));
end $$;
