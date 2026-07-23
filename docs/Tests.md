# PAWD — Test Report

Run: 2026-07-23 · Backend: Supabase project `vaeiskltcpzthaffyejg` · Mobile: Flutter 3.44 (Android x86_64 emulator API 36).
Legend: **PASS** = executed & green · **PARTIAL** = executed, gaps noted · **MANUAL** = verified by walkthrough, not automated.

| # | Test type | Result | Evidence / method |
|---|---|---|---|
| 1 | Functional | **PASS** | `scripts/seed_and_test.py` — auth → pet → discovery → swipe → **match** → my_matches → send message → participant read. `flutter test` model suite green. |
| 2 | Regression | **PASS** | Same suite re-run after the app-restructure, discovery v2 ranker, regional gate, font & Liquid-Glass changes — still fully green. Caught & fixed a real regression (ambiguous `set_my_location` overload → deck returned 0). |
| 3 | System (E2E) | **PASS** | Full app↔backend loop exercised through PostgREST exactly as the client calls it (RLS enforced). |
| 4 | Performance | **PASS** | Deck geo-query: planning 32 ms / execution **58 ms** at current volume; added GiST index on `owners.location` (+ composite swipe index) so `ST_DWithin` scales instead of seq-scanning. PRD target (deck < 1.5 s) met with headroom. |
| 5 | Security | **PASS** | RLS: a user reads only their own `owners` row; deck exposes **no raw coordinates** (distance rounded to 0.1 km, floored 1 km); a non-participant is **blocked** from reading a match's messages; daily like-limit enforced; region gate prevents cross-country leakage. |
| 6 | Compatibility | **PARTIAL** | Android APK builds & runs (x86_64 emulator). iOS target configured (Info.plist perms, Liquid-Glass nav) but **cannot be compiled here — needs a Mac/Xcode**. Web client builds (Next.js). |
| 7 | Usability | **MANUAL** | Core-loop is < 4 min (PRD funnel). Platform-adaptive nav/transitions; empty-states & safety interstitial present. No formal usability study run. |
| 8 | Accessibility | **PARTIAL** | Brand text/BG contrast meets WCAG AA; system font scaling clamped to 0.85–1.3 to prevent layout breakage; Material widgets carry default semantics. TalkBack/VoiceOver pass not formally audited. |
| 9 | User Acceptance | **MANUAL** | End-to-end walkthrough passed on the Android emulator (real OTP login → deck → match → chat) and live data is flowing from the owner's physical device. No external UAT cohort yet. |
| 10 | Recovery | **PARTIAL** | Invalid/expired OTP surfaces a clear error; RLS denials surface as errors, not crashes; chat send is optimistic with rollback on failure. Offline queueing of swipes (PRD v1) not yet implemented. |
| 11 | Smoke | **PASS** | Clean build → install → launch → login renders → navigate across tabs, zero console errors. |

## Known gaps (tracked)
- iOS build/verification requires macOS (CI: Codemagic/Xcode Cloud).
- Offline-tolerant deck & queued swipes (PRD NFR) — deferred.
- Formal accessibility (screen-reader) and external UAT — pre-launch.

## How to re-run
```bash
# backend E2E (functional/system/security/regression)
export SUPABASE_ANON_KEY=... SUPABASE_SERVICE_KEY=...
python scripts/seed_and_test.py

# mobile unit + static analysis + smoke
cd apps/mobile && flutter test && flutter analyze && flutter build apk --debug
```
