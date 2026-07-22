# Software Development Life Cycle (SDLC)

**Model:** Agile (Scrum-lite) with trunk-based-ish Git flow, 2-week sprints, continuous deployment to staging, gated releases to production. Sized for a team of 1–4; every practice below scales down to a solo founder without becoming theater.

---

## Phase 0 — Inception (Weeks 0–2)

**Outputs:** signed-off PRD v1.0, ADRs 0001–0005, data model, OpenAPI skeleton, clickable Figma prototype of the core loop, cold-start launch plan (neighborhood strategy), legal checklist (Ghana Data Protection Act registration, ToS, privacy policy, meetup liability language).

**Gate to proceed:** 10 owner interviews conducted; at least 6 say they'd use it *this month*. Do not skip this — it's cheaper than 18 weeks of code.

---

## Phase 1 — Foundations (Weeks 2–4)

- Monorepo scaffolded per directory structure; `make dev` boots the full stack locally (docker-compose: Postgres+PostGIS, Redis, MinIO, MailHog).
- CI green on empty projects: lint, test, build, Docker image push.
- Staging environment live via Terraform; deploy pipeline working end-to-end *before* any feature exists. Deploying "hello world" to production infrastructure in week 3 removes the scariest unknowns first.
- Auth module + Flutter flavors + design tokens.

---

## Phase 2 — Build (Weeks 4–16): Sprint Cadence

### Sprint rituals (lightweight)
| Ritual | When | Duration |
|---|---|---|
| Sprint planning | Day 1 | 1h — pull from groomed backlog |
| Standup | Async (Slack/Linear thread) | daily |
| Demo + retro | Last day | 45 min, staging build in hand |

### Definition of Ready (a ticket enters a sprint only if)
- Acceptance criteria written (Given/When/Then)
- Analytics events specified
- API contract change (if any) merged to `contracts` first
- Design attached or explicitly "no UI"

### Definition of Done (a ticket closes only if)
- Code + tests merged, CI green
- Deployed to staging and demoed
- Analytics events verified firing in staging
- Docs/runbook updated if operational behavior changed
- No new lint suppressions without a comment

### Branching & review
- `main` = production-ready, always deployable. `develop` optional — prefer short-lived feature branches (`feat/discovery-deck`) merged to `main` behind **feature flags** within ≤3 days.
- Every PR: 1 review (or self-review checklist if solo), CI required, no direct pushes to `main`.
- Conventional Commits (`feat:`, `fix:`, `chore:`) → automated changelog + semantic versioning.

### Feature flags
Use a simple DB/config-backed flag service from day one (or Unleash self-hosted). Ship dark, enable per-environment, kill-switch anything risky (chat, breeding module). Flags are what make trunk-based development safe.

### Sprint sequence (suggested)
| Sprint | Focus |
|---|---|
| 1 | Auth (OTP + Google/Apple), owner profile |
| 2 | Pet profile CRUD, media upload + moderation pipeline |
| 3 | Discovery deck (PostGIS), filters |
| 4 | Swipe engine, match creation (transactional), match list |
| 5 | Chat (Socket.IO gateway, persistence, push on message) |
| 6 | Notifications center, report/block, ban enforcement, hardening |

---

## Phase 3 — Quality Engineering (continuous, not a phase at the end)

### Test pyramid & budgets
| Layer | Tooling | Coverage target |
|---|---|---|
| API unit | Jest | Core domain logic ≥ 80% |
| API integration/e2e | Jest + Testcontainers (real PG/Redis) | Every endpoint happy + auth-failure path |
| Flutter unit/bloc | flutter_test, bloc_test | Blocs ≥ 80% |
| Flutter widget | flutter_test + golden tests | Design-system widgets |
| Mobile E2E | Patrol or integration_test on Firebase Test Lab | The one core-loop test, on real low-end Android devices |
| Load | k6 against staging | Deck endpoint @ 200 RPS, chat @ 1k concurrent sockets |
| Security | CodeQL, `npm audit`/`dart pub audit` in CI, OWASP ZAP baseline against staging weekly | Zero criticals |

### Non-negotiable pre-launch tests
1. Match race condition: two simultaneous mutual likes create exactly one match (DB constraint + test).
2. Location privacy: API never returns raw coordinates of another user's pet — contract test.
3. Blocked users are invisible in deck, search, and chat — e2e test.
4. Token refresh under flaky network (Ghana 3G reality) — mobile integration test.

---

## Phase 4 — Release Management

### Environments
`local → staging (auto-deploy on merge to main) → production (tagged release, manual approval)`

### Mobile release train
- **Weekly** internal builds (Firebase App Distribution).
- **Fortnightly** store releases once public; staged rollout on Play (10% → 50% → 100% over 4 days, halt on crash-rate regression).
- Shorebird or in-app force-update mechanism for critical fixes — you cannot hotfix a mobile binary, so build the "minimum supported version" API gate in week 1.

### Backend releases
- Every merge to `main` deploys to staging; production deploys are tagged (`v1.3.0`), blue-green or rolling with health checks.
- **DB migrations:** expand → migrate → contract pattern only. Never a breaking migration in the same release as the code that requires it.
- Rollback: previous image redeploy ≤ 5 minutes; migrations must be backward-compatible one version.

### Release checklist (excerpt)
- [ ] Changelog generated, version tagged
- [ ] Staging smoke suite green
- [ ] Feature flags default states confirmed
- [ ] Sentry release created, sourcemaps/symbols uploaded
- [ ] Rollback plan named in the release PR

---

## Phase 5 — Operations & Monitoring

| Concern | Tooling (lean stack) |
|---|---|
| Errors | Sentry (API + Flutter) |
| Metrics/uptime | Grafana Cloud free tier or Better Stack; alert on p95 latency, 5xx rate, socket disconnect spikes |
| Logs | Structured JSON → Loki/CloudWatch |
| Product analytics | PostHog (self-hosted, cheap, GDPR-friendly) |
| On-call | Solo/small team: Better Stack phone alerts for SEV-1 only |
| Backups | Automated daily PG backups + PITR; **monthly restore drill** via `backup-verify.sh` |

### Incident severities
- **SEV-1:** app down, data breach, animal-welfare emergency surfaced in-app → respond < 30 min, postmortem within 72h (blameless, written).
- **SEV-2:** core feature degraded (chat down, deck empty) → respond < 4h.
- **SEV-3:** everything else → next sprint.

### Trust & safety operations (this is an ops function, not a feature)
- Moderation queue SLA: 24h for all reports, 2h for welfare/safety categories.
- Weekly review of report patterns → policy updates in `docs/trust-and-safety/`.
- Ban-evasion audit monthly.

---

## Phase 6 — Iterate (post-launch loop)

Weekly: funnel review against §7 PRD metrics → hypothesis → smallest testable change → flag-gated ship → measure. Kill features that don't move Weekly Matched Conversations. The roadmap (v1.1 premium + breeding, v1.2 meetups) is a hypothesis list, not a promise.

---

## Governance & Hygiene

- **Secrets:** never in git; use environment secret manager (Doppler/Infisical or cloud-native). `.env.example` documents every variable.
- **Dependencies:** Renovate bot, weekly auto-PRs, majors reviewed manually.
- **Data protection:** register with Ghana Data Protection Commission before public launch; data retention policy documented (chat: 12 months post-unmatch; deleted accounts purged in 30 days).
- **Access:** least privilege; production DB access via bastion + audit log only; no shared accounts.
- **Docs debt rule:** any operational surprise gets a runbook entry the same week.

---

## Solo-founder reality check

If it's just you for the first months, the above compresses to: trunk-based on `main` with CI, feature flags, Testcontainers e2e for the API, one Patrol core-loop test, Sentry + PostHog, staged Play rollouts, and the pre-launch non-negotiable tests. Everything else activates as the team grows — but the *structure* (monorepo, contracts, flags, migrations discipline) costs almost nothing now and is brutal to retrofit.
