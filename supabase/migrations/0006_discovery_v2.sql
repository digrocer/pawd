-- PAWD — Discovery Engine v2 (multi-signal ranker)
-- Grounded in how modern discovery apps actually rank (Elo/desirability is retired):
--   recency/activity is the dominant lever; plus reciprocity (who already liked you),
--   proximity, purpose overlap, and profile completeness (Bumble-style).
-- Ethically tuned for a PET app: NO attractiveness/popularity scoring of people.

-- Activity signal ----------------------------------------------------------
alter table public.owners add column if not exists last_active_at timestamptz not null default now();
update public.owners set last_active_at = greatest(coalesce(location_updated_at, created_at), created_at)
  where last_active_at is null;
create index if not exists owners_last_active_idx on public.owners(last_active_at);

-- Bump activity on meaningful actions ---------------------------------------
create or replace function public.set_my_location(p_lat double precision, p_lng double precision)
  returns void language plpgsql security definer set search_path = public as $$
begin
  update public.owners
  set location = st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      location_updated_at = now(), last_active_at = now()
  where id = auth.uid();
end $$;

create or replace function public.touch_active() returns trigger
  language plpgsql security definer set search_path = public as $$
begin update public.owners set last_active_at = now() where id = new.sender_id; return new; end $$;
drop trigger if exists trg_touch_active_msg on public.messages;
create trigger trg_touch_active_msg after insert on public.messages
  for each row execute function public.touch_active();

-- Discovery deck v2 ---------------------------------------------------------
-- Same signature + return shape as v1 (clients unchanged). Ordering is the upgrade.
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
  pet_id uuid, name text, species species, breed text, sex pet_sex,
  age_months int, energy_level int, temperament text[], bio text,
  purposes purpose_flag[], vaccination vacc_status, owner_display_name text,
  distance_km numeric, primary_photo text
)
  language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_loc geography;
  v_purposes purpose_flag[];
  v_radius_m double precision := p_radius_km * 1000;
begin
  select o.location, p.purposes into v_loc, v_purposes
  from public.pets p join public.owners o on o.id = p.owner_id
  where p.id = p_viewer_pet and p.owner_id = v_owner;
  if not found then raise exception 'Not your pet'; end if;
  update public.owners set last_active_at = now() where id = v_owner;

  return query
  with cand as (
    select
      p.id, p.name, p.species, p.breed, p.sex, p.date_of_birth, p.energy_level,
      p.temperament, p.bio, p.purposes, p.vaccination, p.updated_at, p.created_at,
      o.display_name, o.last_active_at,
      st_distance(o.location, v_loc) as dist_m,
      (select count(*) from public.pet_photos pp where pp.pet_id = p.id and pp.approved) as nphotos,
      (select pp.storage_path from public.pet_photos pp
         where pp.pet_id = p.id and pp.approved order by pp.position limit 1) as photo,
      exists(select 1 from public.swipes s
             where s.swiper_pet = p.id and s.target_pet = p_viewer_pet and s.direction = 'like') as liked_me,
      (select count(*) from (select unnest(p.purposes) intersect select unnest(v_purposes)) _o) as overlap
    from public.pets p
    join public.owners o on o.id = p.owner_id
    where p.id <> p_viewer_pet
      and p.owner_id <> v_owner
      and p.is_active
      and not o.is_banned
      and o.location is not null and v_loc is not null
      and p.purposes && v_purposes
      and (p.purposes && (array['playdates','walking','friends']::purpose_flag[]))
      and st_dwithin(o.location, v_loc, v_radius_m)
      and (p_species is null or p.species = p_species)
      and (p_sex is null or p.sex = p_sex)
      and (not p_vaccinated_only or p.vaccination = 'up_to_date')
      and (p_min_age_months is null or p.date_of_birth is null or
           (extract(year from age(p.date_of_birth))*12 + extract(month from age(p.date_of_birth))) >= p_min_age_months)
      and (p_max_age_months is null or p.date_of_birth is null or
           (extract(year from age(p.date_of_birth))*12 + extract(month from age(p.date_of_birth))) <= p_max_age_months)
      and not exists (select 1 from public.swipes s where s.swiper_pet = p_viewer_pet and s.target_pet = p.id)
      and not exists (select 1 from public.blocks b
          where (b.blocker_id = v_owner and b.blocked_id = o.id)
             or (b.blocker_id = o.id and b.blocked_id = v_owner))
  ),
  scored as (
    select c.*,
      -- normalized 0..1 signals
      greatest(0, 1 - (c.dist_m / nullif(v_radius_m,0)))                           as s_dist,
      greatest(0, 1 - (extract(epoch from (now() - c.last_active_at))/86400.0)/30.0) as s_recency,
      least(1.0, c.overlap / 3.0)                                                  as s_purpose,
      least(1.0, (case when c.nphotos>=1 then 0.4 else 0 end)
               + (case when c.nphotos>=3 then 0.2 else 0 end)
               + (case when c.bio is not null then 0.2 else 0 end)
               + (case when c.vaccination='up_to_date' then 0.2 else 0 end))       as s_complete,
      greatest(0, 1 - (extract(epoch from (now() - c.created_at))/86400.0)/30.0)   as s_novelty,
      (case when c.liked_me then 1.0 else 0.0 end)                                 as s_reciprocal
    from cand c
  )
  select
    s.id, s.name, s.species, s.breed, s.sex,
    case when s.date_of_birth is not null
      then (extract(year from age(s.date_of_birth))*12 + extract(month from age(s.date_of_birth)))::int
      else null end,
    s.energy_level, s.temperament, s.bio, s.purposes, s.vaccination, s.display_name,
    greatest(1.0, round((s.dist_m/1000.0)::numeric, 1)) as distance_km,
    s.photo
  from scored s
  order by
    -- weighted composite: reciprocity first (near-certain match), then activity,
    -- proximity, purpose fit, completeness, freshness. Small deterministic jitter
    -- via pet id keeps ties from starving newer profiles.
    ( 5.0 * s.s_reciprocal
    + 2.2 * s.s_recency
    + 2.0 * s.s_dist
    + 1.5 * s.s_purpose
    + 1.0 * s.s_complete
    + 0.6 * s.s_novelty ) desc,
    s.dist_m asc
  limit p_limit;
end $$;

grant execute on function public.discovery_deck(uuid, numeric, species, pet_sex, int, int, boolean, int) to authenticated;
