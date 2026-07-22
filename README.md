# 🐾 PAWD

A pet-centric social platform — **the pet is the profile**. Owners discover nearby
pets for playdates, walks and companionship through location-based swipe matching,
then chat once it's mutual. Built mobile-first for Accra (and beyond).

This repo is the **MVP (P0)** of the [PRD](docs/01-PRD.md): a working core loop on a
Supabase backend with a Next.js PWA front end.

> **Status:** core loop live and verified end-to-end (auth → pet profile → discovery →
> swipe → match → chat → report/block). Breeding verification, premium/MoMo, vet portal
> and native apps are deferred per the PRD roadmap.

---

## What's built

| Area | Implemented |
|---|---|
| **Auth** | Passwordless email OTP (Supabase Auth). Owner row auto-provisioned on signup. 18+ attestation. |
| **Onboarding** | Owner details + location capture → first pet, in one flow. |
| **Pet profiles** | Full CRUD, up to 5 pets/owner, 1–6 photos, temperament, energy, purposes, vaccination, bio. Hide/show + delete. |
| **Discovery** | PostGIS `ST_DWithin` deck scored by distance × purpose overlap × recency. Filters: distance, species, sex, vaccination. Swipe (drag or buttons). |
| **Matching** | Race-safe mutual-like → single match (canonical ordering + unique constraint + trigger). Daily like limit (25, free tier). |
| **Chat** | 1:1, match-gated, Supabase Realtime, safety interstitial, optimistic send. |
| **Trust & safety** | Report (5 categories), block + unmatch, RLS-enforced invisibility, moderation-ready `reports` queue. |
| **Privacy** | Raw coordinates **never** leave the server — deck returns distance rounded to 0.1 km, floored at 1 km. |

## Architecture

```
Next.js 14 (App Router, PWA)  ──►  Supabase
  ├─ middleware: session refresh + route guards       ├─ Postgres 17 + PostGIS
  ├─ server components (SSR reads)                     ├─ Auth (email OTP)
  ├─ client components (swipe, chat, forms)            ├─ Storage (pet-photos, chat-images)
  └─ @supabase/ssr cookie sessions                     ├─ Realtime (messages)
                                                       └─ RLS + SECURITY DEFINER RPCs
```

The security model is **RLS-first**: clients can only read their own `owners` row.
All cross-user data (the deck, matches, other owners' public info) flows through
`SECURITY DEFINER` RPCs that return curated columns only — which is how location
privacy is enforced structurally, not by convention.

Key RPCs (`supabase/migrations/0002…`): `discovery_deck`, `record_swipe`,
`my_matches`, `set_my_location`, `block_owner`.

## Project layout

```
app/                     Next.js routes (login, onboarding, (main)/*, chat/*)
components/              SwipeDeck, PetForm, ChatRoom, BottomNav
lib/                     supabase clients (browser/server), shared types
middleware.ts            auth session + route protection
supabase/migrations/     0001 schema · 0002 matching+discovery · 0003 RLS · 0004 storage · 0005 realtime
scripts/                 apply_sql.py (run a migration), seed_and_test.py (e2e check + demo seed)
docs/                    PRD, directory-structure, SDLC
```

## Running locally

Requires Node 18+ and a Supabase project.

```bash
npm install
cp .env.example .env.local   # fill in NEXT_PUBLIC_SUPABASE_URL + ANON key
npm run dev                  # http://localhost:3000
```

### Applying the database schema

Migrations are plain SQL. Apply them in order to a fresh project:

```bash
export SUPABASE_ACCESS_TOKEN=sbp_xxx        # Supabase personal access token
export SUPABASE_PROJECT_REF=your_ref
for f in supabase/migrations/*.sql; do python scripts/apply_sql.py "$f"; done
```

(Or paste each file into the Supabase SQL editor. If you use the Supabase CLI,
`supabase db push` works too.)

### Seed demo pets + run the end-to-end check

```bash
export SUPABASE_ANON_KEY=...  SUPABASE_SERVICE_KEY=...
python scripts/seed_and_test.py
```

This creates demo pets around Accra and verifies the whole core loop against a live
project (discovery, location privacy, match creation, chat access control, daily
like limit) — all through PostgREST with RLS enforced, exactly as the app does.

## Security notes

- **No secrets in git.** `.env.local`, `.claude/settings.local.json` are ignored;
  scripts read keys from env vars. Only the public anon key is ever shipped to the client.
- **Email OTP** requires a deliverable inbox — Supabase rejects domains without MX records.
- Rotate any key that has been shared during development.

## Roadmap (per PRD)

v1.1 — breeding verification + vet portal, premium (Mobile Money first).
v1.2 — events/meetups, ratings, voice notes. Native Flutter clients can consume this
same Supabase backend unchanged.
