-- PAWD — Core schema (P0 MVP)
-- Pet-centric social platform: profiles, pets, discovery, swipes, matches, chat, safety.
-- Location privacy: raw coordinates never exposed to other users; only rounded distance.

-- ─────────────────────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────────────────────
create extension if not exists postgis;
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────────────────
do $$ begin
  create type species        as enum ('dog', 'cat');
  create type pet_sex        as enum ('male', 'female');
  create type purpose_flag   as enum ('playdates', 'walking', 'friends', 'breeding');
  create type vacc_status    as enum ('unknown', 'partial', 'up_to_date');
  create type swipe_dir      as enum ('like', 'pass');
  create type report_reason  as enum ('fake_profile', 'welfare_concern', 'harassment', 'scam', 'spam');
  create type report_status  as enum ('open', 'triaged', 'actioned', 'dismissed');
exception when duplicate_object then null; end $$;

-- ─────────────────────────────────────────────────────────────
-- Owners (1:1 with auth.users)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.owners (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default 'Pet Owner',
  photo_url     text,
  city          text,
  area          text,
  phone_verified boolean not null default false,
  -- Raw location. NEVER selected by clients directly; only via discovery RPC as distance.
  location      geography(point, 4326),
  location_updated_at timestamptz,
  age_attested  boolean not null default false,   -- FR-23: 18+ self-attest
  is_banned     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- Pets
-- ─────────────────────────────────────────────────────────────
create table if not exists public.pets (
  id            uuid primary key default uuid_generate_v4(),
  owner_id      uuid not null references public.owners(id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 60),
  species       species not null,
  breed         text not null default 'Mixed/Unknown',
  sex           pet_sex not null,
  date_of_birth date,
  weight_kg     numeric(5,2),
  neutered      boolean,
  vaccination   vacc_status not null default 'unknown',
  temperament   text[] not null default '{}' check (array_length(temperament,1) is null or array_length(temperament,1) <= 5),
  energy_level  int not null default 3 check (energy_level between 1 and 5),
  bio           text check (char_length(bio) <= 280),
  purposes      purpose_flag[] not null default '{playdates}' check (array_length(purposes,1) between 1 and 4),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists pets_owner_idx on public.pets(owner_id);
create index if not exists pets_species_idx on public.pets(species) where is_active;

-- Enforce max 5 pets per owner (FR-7)
create or replace function public.enforce_pet_limit() returns trigger
  language plpgsql as $$
begin
  if (select count(*) from public.pets where owner_id = new.owner_id) >= 5 then
    raise exception 'Pet limit reached (max 5 per owner)';
  end if;
  return new;
end $$;
drop trigger if exists trg_pet_limit on public.pets;
create trigger trg_pet_limit before insert on public.pets
  for each row execute function public.enforce_pet_limit();

-- ─────────────────────────────────────────────────────────────
-- Pet photos (1–6, ordered; first is primary)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.pet_photos (
  id         uuid primary key default uuid_generate_v4(),
  pet_id     uuid not null references public.pets(id) on delete cascade,
  storage_path text not null,               -- path in the 'pet-photos' bucket
  position   int not null default 0,
  approved   boolean not null default true, -- FR-8: moderation; auto-approve at MVP
  created_at timestamptz not null default now(),
  unique (pet_id, position)
);
create index if not exists pet_photos_pet_idx on public.pet_photos(pet_id);

-- ─────────────────────────────────────────────────────────────
-- Blocks (mutual invisibility) — FR-20
-- ─────────────────────────────────────────────────────────────
create table if not exists public.blocks (
  blocker_id uuid not null references public.owners(id) on delete cascade,
  blocked_id uuid not null references public.owners(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ─────────────────────────────────────────────────────────────
-- Swipes (like / pass) — pet acts on pet
-- ─────────────────────────────────────────────────────────────
create table if not exists public.swipes (
  id           uuid primary key default uuid_generate_v4(),
  swiper_pet   uuid not null references public.pets(id) on delete cascade,
  target_pet   uuid not null references public.pets(id) on delete cascade,
  direction    swipe_dir not null,
  created_at   timestamptz not null default now(),
  unique (swiper_pet, target_pet),
  check (swiper_pet <> target_pet)
);
create index if not exists swipes_target_idx on public.swipes(target_pet, direction);
create index if not exists swipes_swiper_idx on public.swipes(swiper_pet);

-- ─────────────────────────────────────────────────────────────
-- Matches — canonical ordering (pet_a < pet_b) prevents duplicates.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.matches (
  id         uuid primary key default uuid_generate_v4(),
  pet_a      uuid not null references public.pets(id) on delete cascade,
  pet_b      uuid not null references public.pets(id) on delete cascade,
  created_at timestamptz not null default now(),
  is_active  boolean not null default true,
  unique (pet_a, pet_b),
  check (pet_a < pet_b)
);
create index if not exists matches_pet_a_idx on public.matches(pet_a);
create index if not exists matches_pet_b_idx on public.matches(pet_b);

-- ─────────────────────────────────────────────────────────────
-- Messages — 1:1 chat unlocked by a match (FR-15)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.messages (
  id         uuid primary key default uuid_generate_v4(),
  match_id   uuid not null references public.matches(id) on delete cascade,
  sender_id  uuid not null references public.owners(id) on delete cascade,
  body       text check (char_length(body) <= 2000),
  image_path text,
  created_at timestamptz not null default now(),
  check (body is not null or image_path is not null)
);
create index if not exists messages_match_idx on public.messages(match_id, created_at);

-- ─────────────────────────────────────────────────────────────
-- Reports — FR-19
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reports (
  id          uuid primary key default uuid_generate_v4(),
  reporter_id uuid not null references public.owners(id) on delete cascade,
  target_owner uuid references public.owners(id) on delete set null,
  target_pet  uuid references public.pets(id) on delete set null,
  reason      report_reason not null,
  detail      text check (char_length(detail) <= 1000),
  status      report_status not null default 'open',
  created_at  timestamptz not null default now()
);
create index if not exists reports_status_idx on public.reports(status);

-- ─────────────────────────────────────────────────────────────
-- updated_at trigger
-- ─────────────────────────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger
  language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists trg_owners_touch on public.owners;
create trigger trg_owners_touch before update on public.owners
  for each row execute function public.touch_updated_at();
drop trigger if exists trg_pets_touch on public.pets;
create trigger trg_pets_touch before update on public.pets
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- Auto-create owner row on signup
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.owners (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', 'Pet Owner'))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
