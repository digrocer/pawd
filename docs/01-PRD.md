# Product Requirements Document (PRD)

**Product:** PAWD
**Version:** 1.0 — MVP
**Author:** Dee
**Status:** Draft
**Last updated:** July 2026

---

## 1. Overview

### 1.1 Problem Statement
Pet owners have no structured, trustworthy way to find nearby pets for socialization (playdates, walks, companionship) or to find verified, health-screened partners for responsible breeding. Existing channels — WhatsApp groups, Facebook groups, word of mouth — lack verification, health records, location awareness, and safety controls. Irresponsible breeding thrives in this vacuum.

### 1.2 Solution
A mobile-first, pet-centric social platform where the **pet is the profile**, discovery is location-based swipe matching, and trust is built through layered verification (owner identity, vaccination, vet certification, microchip). Breeding is a gated, separately-moderated flow with stricter requirements than playdates.

### 1.3 Target Market (initial)
- **Primary:** Urban dog and cat owners in Accra/Tema, ages 20–45, smartphone users.
- **Secondary:** Veterinary clinics, groomers, pet stores, trainers (B2B advertisers, verification partners).
- **Expansion:** Kumasi, Lagos, Nairobi — pan-African urban pet ownership is growing fast with a middle class that treats pets as family.

### 1.4 Success Definition
Within 6 months of public launch: 5,000 registered pet profiles in Greater Accra, 30% weekly active rate, 500+ successful matches/month, at least 3 vet clinic verification partners.

---

## 2. Goals & Non-Goals

### Goals (MVP)
1. Owners can create rich pet profiles in under 3 minutes.
2. Location-based discovery with swipe/like matching.
3. Mutual-match chat with photo sharing.
4. Basic filters (species, breed, distance, sex, purpose, vaccination).
5. Reporting/blocking and baseline trust signals.

### Non-Goals (MVP — explicitly deferred)
- Breeding verification workflow (v1.1 — needs vet partnerships first)
- AI breed/age estimation (v2)
- Events/meetups module (v1.2)
- Payments & premium tier (v1.1, after retention is proven)
- Ratings/reviews (v1.2 — needs match volume to be meaningful)
- Web app (mobile only at launch)

**Rationale:** The core risk to validate is *"will pet owners in Accra swipe, match, and actually meet?"* Everything else is scaffolding on top of that answer.

---

## 3. User Personas

| Persona | Description | Primary Need |
|---|---|---|
| **Ama, 27** — The Socializer | Golden retriever owner in East Legon, dog is high-energy and alone all day | Playmates & walking buddies nearby |
| **Kwame, 35** — The Responsible Breeder | Owns a pedigree German Shepherd, wants one litter with a health-tested partner | Verified breeding partner, health transparency |
| **Efua, 22** — The New Owner | First-time cat owner, unsure about socialization and vet care | Community, guidance, trusted local vets |
| **Dr. Mensah** — The Vet Partner | Runs a clinic in Osu | Client acquisition; willing to verify records for visibility |

---

## 4. Functional Requirements

### 4.1 Authentication & Onboarding (P0)
- FR-1: Sign up via phone number (OTP), Google, or Apple. **Phone-first for Ghana** — email is secondary.
- FR-2: Owner profile: name, photo, city/area, phone verified badge.
- FR-3: Onboarding wizard: create first pet profile immediately after signup (no empty-state dead end).
- FR-4: Location permission with graceful degradation (manual area selection if denied).

### 4.2 Pet Profiles (P0)
- FR-5: Fields: name, species (dog/cat at launch), breed (searchable list + "mixed/unknown"), sex, date of birth, weight, neutered status, vaccination status (self-declared at MVP), temperament tags (max 5), energy level (1–5), photos (1–6, first is required), short bio (280 chars).
- FR-6: Purpose flags: Playdates / Walking buddy / Pet friends / Breeding (breeding flag visible but discovery-gated until v1.1).
- FR-7: One owner can manage multiple pets (max 5 free).
- FR-8: Photo moderation pipeline: automated NSFW/off-topic detection before publish, human review queue for flags.

### 4.3 Discovery & Matching (P0)
- FR-9: Card stack of nearby pets, ordered by a score: distance (geohash proximity) × purpose overlap × recency of activity.
- FR-10: Swipe right (like), left (pass), with undo (premium later).
- FR-11: Mutual like → Match created → both owners notified.
- FR-12: Filters: species, breed, sex, distance radius (1–50 km), purpose, vaccination declared, age range.
- FR-13: Daily like limit (e.g., 25) on free tier — protects quality and creates future monetization lever.
- FR-14: Only pets with the *same purpose selected* appear in each other's decks. Playdate seekers never see breeding-only profiles and vice versa. **This separation is a hard product rule, not a filter default.**

### 4.4 Chat (P0)
- FR-15: 1:1 owner-to-owner chat unlocked only after a match.
- FR-16: Text + images. Voice notes and live location deferred to v1.1.
- FR-17: Safety interstitial on first message: meet-in-public guidance, report shortcut.
- FR-18: Unmatch dissolves the conversation for both sides.

### 4.5 Trust & Safety (P0 — non-negotiable at launch)
- FR-19: Report user/pet (categories: fake profile, animal welfare concern, harassment, scam, spam) with mandatory triage SLA of 24h.
- FR-20: Block (mutual invisibility, chat frozen).
- FR-21: Device + phone-number based ban enforcement.
- FR-22: Animal-welfare escalation path: reports flagged "welfare concern" route to a dedicated queue with guidance to contact Ghana SPCA / veterinary authorities where warranted.
- FR-23: Minimum owner age 18 (self-attested at MVP; enforced via payment KYC later).

### 4.6 Notifications (P0)
- FR-24: Push (FCM): new match, new message, likes summary (batched daily).
- FR-25: In-app notification center; per-category opt-out.

### 4.7 Breeding Module (P1 — v1.1, spec'd now so architecture supports it)
- FR-26: Breeding discovery gated behind a "Verified for Breeding" status requiring: owner ID verification, uploaded vet certificate (reviewed), vaccination proof, pet age within species/breed-appropriate breeding window, not spayed/neutered.
- FR-27: Vet partner portal (web) to attest records — this is the moat. A vet-attested badge is worth 100 self-declared checkboxes.
- FR-28: Breeding chats include an in-chat responsible-breeding checklist and disclosure prompts (genetic tests, prior litters).
- FR-29: Hard rules engine: block breeding matches for underage pets, excessive litter frequency flags via community reports.

### 4.8 Premium & Monetization (P1 — v1.1)
- Free: 25 likes/day, 1–5 pets, standard filters.
- Premium (monthly, **Mobile Money first** — MTN MoMo, Vodafone Cash, then cards via Paystack): unlimited likes, see who liked you, undo, advanced filters, profile boost.
- B2B: verified vet/groomer/store profiles with local placement (not banner ads — native "Trusted Local Services" directory).

---

## 5. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | Deck load < 1.5s on 3G; image delivery via CDN with responsive sizes; app cold start < 3s on mid-range Android (this is your real device profile in Ghana — test on a Tecno/Infinix, not a Pixel) |
| **Availability** | 99.5% MVP target; graceful offline mode (cached deck, queued swipes) |
| **Scalability** | Architecture must handle 100k users without redesign: stateless API, Redis-backed sessions/queues, PostGIS for geo queries |
| **Security** | OWASP ASVS L1 minimum; JWT with short-lived access + refresh rotation; rate limiting per IP and per account; signed URLs for media; encrypted at rest (DB + object storage) |
| **Privacy** | Location fuzzing — never show exact coordinates, only distance rounded to 0.1 km and never below 1 km granularity on profiles; Ghana Data Protection Act, 2012 (Act 843) registration; GDPR-aligned data export/delete for future EU expansion |
| **Data residency** | No hard constraint, but keep latency low: host in EU-West or South Africa region (AWS af-south-1 / GCP) |
| **Accessibility** | WCAG AA color contrast, dynamic type support, TalkBack/VoiceOver on core flows |
| **Localization** | English at launch; string externalization from day one (Twi, French for expansion) |
| **Observability** | Structured logs, error tracking (Sentry), product analytics (PostHog self-hosted or Mixpanel), crash-free rate > 99.3% |

---

## 6. Key User Flows

1. **Signup → First Pet → First Swipe** (must be < 4 minutes end-to-end; this funnel is your #1 metric)
2. **Swipe → Match → Chat → Meetup arranged** (activation)
3. **Report → Triage → Action** (safety)
4. **(v1.1) Verification upload → Vet attestation → Breeding unlock** (trust)

---

## 7. Metrics & Instrumentation

**North Star:** Weekly Matched Conversations (matches with ≥3 message exchanges in a week).

| Funnel | Metric | Target (month 3) |
|---|---|---|
| Acquisition | Signups/week | 300 |
| Activation | % signups completing pet profile + 10 swipes in 48h | 60% |
| Engagement | Matches per WAU per week | 0.8 |
| Retention | Week-4 retention | 25% |
| Trust | Reports per 1k matches | < 15, with 24h resolution |
| Quality | Crash-free sessions | > 99.3% |

Every FR above must ship with its analytics events defined *in the same ticket* — no retro-instrumentation.

---

## 8. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Cold-start / empty decks | High | Fatal | Launch neighborhood-by-neighborhood (East Legon → Osu → Cantonments); seed via vet clinic partnerships and dog-walker communities; show "notify me" waitlist outside launch zones |
| Irresponsible breeding facilitated via playdate chats | Medium | High (reputational) | Keyword flagging in chat for breeding solicitation outside verified flow; clear ToS; report category |
| Animal welfare incidents at meetups | Medium | High | In-app public-place guidance, no exact-location sharing pre-match, partnership with SPCA for reporting |
| Low smartphone GPS accuracy / data costs | Medium | Medium | Manual area selection, aggressive image compression, offline-tolerant design |
| Payment friction for premium | High | Medium | MoMo-first; delay monetization until retention proven |
| Fake/scam profiles (pet sales scams are rampant in GH Facebook groups) | High | High | Phone verification mandatory, photo moderation, "no sales" ToS with enforcement, verified badges |

---

## 9. Release Plan

| Milestone | Scope | Target |
|---|---|---|
| **Alpha** | Internal + 30 friendly users, core loop only | Week 8 |
| **Closed Beta** | 300 users, one neighborhood, TestFlight/Play Internal | Week 12 |
| **v1.0 Public (Accra)** | MVP scope, Play Store + App Store | Week 18 |
| **v1.1** | Premium + MoMo, breeding verification, vet portal | Week 26 |
| **v1.2** | Meetups/events, ratings, voice notes | Week 34 |

---

## 10. Open Questions

1. Dogs-only at launch, or dogs + cats? (Recommendation: dogs only — density beats breadth for a matching product.)
2. Trademark & domain check — "PAWD" availability in Ghana, app stores, and pawd.app / pawd.com / getpawd.com.
3. Vet partnership economics: free verification in exchange for directory placement, or revenue share?
4. Legal review of liability waiver for meetups arranged via the platform.
