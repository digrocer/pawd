# Directory Structure — Production Monorepo

**Recommendation:** a single monorepo (`pawd/`) containing the Flutter app, NestJS API, shared packages, and infrastructure-as-code. One repo = atomic changes across API contract + client, one CI pipeline, one source of truth. Split later only if team size forces it.

```
pawd/
├── README.md
├── CONTRIBUTING.md
├── LICENSE
├── .gitignore
├── .editorconfig
├── docker-compose.yml              # Local dev: postgres+postgis, redis, minio, mailhog
├── Makefile                        # make dev / test / lint / migrate — one-command everything
├── turbo.json                      # Task orchestration for JS workspaces (optional but recommended)
├── package.json                    # Workspace root (npm/pnpm workspaces)
│
├── .github/
│   ├── workflows/
│   │   ├── api-ci.yml              # Lint → test → build → docker push (on apps/api changes)
│   │   ├── mobile-ci.yml           # Analyze → test → build APK/IPA (on apps/mobile changes)
│   │   ├── deploy-staging.yml      # Auto-deploy develop → staging
│   │   ├── deploy-production.yml   # Tagged release → production (manual approval gate)
│   │   └── codeql.yml              # Security scanning
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── safety_incident.md      # Trust & safety issues get their own template + SLA
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
│
├── docs/
│   ├── prd/
│   │   └── PRD-v1.0.md
│   ├── architecture/
│   │   ├── overview.md             # C4 diagrams (use Mermaid, renders on GitHub)
│   │   ├── adr/                    # Architecture Decision Records
│   │   │   ├── 0001-monorepo.md
│   │   │   ├── 0002-postgis-for-geo.md
│   │   │   └── 0003-socketio-vs-firebase.md
│   │   └── data-model.md
│   ├── api/                        # Generated OpenAPI spec lands here
│   ├── runbooks/                   # "DB is down", "moderation queue overflow", etc.
│   └── trust-and-safety/
│       ├── moderation-policy.md
│       └── breeding-verification-policy.md
│
├── apps/
│   ├── mobile/                     # ═══ Flutter app ═══
│   │   ├── pubspec.yaml
│   │   ├── analysis_options.yaml   # very_good_analysis lint set
│   │   ├── android/
│   │   ├── ios/
│   │   ├── assets/
│   │   │   ├── images/
│   │   │   ├── icons/
│   │   │   └── translations/       # en.json, tw.json — externalized from day 1
│   │   ├── lib/
│   │   │   ├── main_dev.dart       # Flavor entrypoints
│   │   │   ├── main_staging.dart
│   │   │   ├── main_prod.dart
│   │   │   ├── app/
│   │   │   │   ├── app.dart        # Root widget, theming
│   │   │   │   ├── router.dart     # go_router config, auth guards
│   │   │   │   └── di.dart         # Dependency injection (get_it + injectable)
│   │   │   ├── core/
│   │   │   │   ├── config/         # Env config per flavor
│   │   │   │   ├── network/        # Dio client, interceptors (auth refresh, retry)
│   │   │   │   ├── storage/        # Secure storage, local cache (drift/hive)
│   │   │   │   ├── analytics/      # Event tracking abstraction
│   │   │   │   ├── error/          # Failure types, Sentry integration
│   │   │   │   └── utils/
│   │   │   ├── features/           # ═ Feature-first, each self-contained ═
│   │   │   │   ├── auth/
│   │   │   │   │   ├── data/       # repositories_impl, data sources, DTOs
│   │   │   │   │   ├── domain/     # entities, repository interfaces, use cases
│   │   │   │   │   └── presentation/  # screens, widgets, blocs/cubits
│   │   │   │   ├── onboarding/
│   │   │   │   ├── pet_profile/
│   │   │   │   ├── discovery/      # Deck, swipe engine, filters
│   │   │   │   ├── matches/
│   │   │   │   ├── chat/
│   │   │   │   ├── notifications/
│   │   │   │   ├── safety/         # Report, block flows
│   │   │   │   └── settings/
│   │   │   └── shared/
│   │   │       ├── widgets/        # Design system: PawButton, PetCard, etc.
│   │   │       └── theme/
│   │   ├── test/                   # Mirrors lib/ structure
│   │   │   ├── features/
│   │   │   └── helpers/            # Fixtures, mocks, pump helpers
│   │   └── integration_test/
│   │       └── core_loop_test.dart # Signup → profile → swipe → match
│   │
│   ├── api/                        # ═══ NestJS backend ═══
│   │   ├── package.json
│   │   ├── nest-cli.json
│   │   ├── tsconfig.json
│   │   ├── Dockerfile              # Multi-stage, distroless final image
│   │   ├── .env.example            # Every env var documented; never commit .env
│   │   ├── prisma/                 # (or drizzle/ — see ADR-0004)
│   │   │   ├── schema.prisma
│   │   │   ├── migrations/
│   │   │   └── seed.ts
│   │   ├── src/
│   │   │   ├── main.ts             # Bootstrap: helmet, CORS, validation pipe, Swagger
│   │   │   ├── app.module.ts
│   │   │   ├── common/
│   │   │   │   ├── guards/         # JwtAuthGuard, RolesGuard, ThrottlerGuard
│   │   │   │   ├── interceptors/   # Logging, transform, timeout
│   │   │   │   ├── filters/        # Global exception filter
│   │   │   │   ├── decorators/     # @CurrentUser(), @Public()
│   │   │   │   └── pipes/
│   │   │   ├── config/             # Typed config module, validation via zod/joi
│   │   │   ├── modules/
│   │   │   │   ├── auth/           # OTP, OAuth, JWT issue/refresh/revoke
│   │   │   │   ├── users/          # Owner accounts
│   │   │   │   ├── pets/           # Pet CRUD, photo management
│   │   │   │   ├── media/          # Signed upload URLs, moderation hooks
│   │   │   │   ├── discovery/      # Deck generation, PostGIS queries, scoring
│   │   │   │   ├── swipes/         # Like/pass, match detection (transactional)
│   │   │   │   ├── matches/
│   │   │   │   ├── chat/           # Socket.IO gateway + message persistence
│   │   │   │   ├── notifications/  # FCM dispatch, preference management
│   │   │   │   ├── moderation/     # Reports, blocks, bans, review queue
│   │   │   │   ├── verification/   # (v1.1) documents, vet attestations
│   │   │   │   └── admin/          # Internal moderation/ops endpoints
│   │   │   ├── jobs/               # BullMQ processors: image moderation,
│   │   │   │                       #   notification batching, deck precompute
│   │   │   └── database/           # Prisma service, transaction helpers
│   │   ├── test/
│   │   │   ├── unit/
│   │   │   └── e2e/                # Testcontainers: real postgres+redis
│   │   └── openapi/                # Generated spec (source for client codegen)
│   │
│   └── admin-web/                  # (v1.1) Moderation + vet portal — Next.js/React
│       └── ...
│
├── packages/                       # Shared JS/TS code
│   ├── contracts/                  # OpenAPI-generated types + zod schemas —
│   │                               #   single source of truth for API shapes
│   ├── eslint-config/
│   └── tsconfig/
│
├── infra/                          # ═══ Infrastructure as Code ═══
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── network/
│   │   │   ├── database/           # Managed Postgres + PostGIS, backups, PITR
│   │   │   ├── cache/              # Managed Redis
│   │   │   ├── storage/            # S3/R2 buckets + CDN
│   │   │   └── app/                # Container service (ECS/Cloud Run/Fly.io)
│   │   └── environments/
│   │       ├── staging/
│   │       └── production/
│   └── scripts/
│       ├── backup-verify.sh        # Restore drills — a backup you haven't
│       │                           #   restored is a hope, not a backup
│       └── seed-staging.sh
│
└── tools/
    └── codegen/                    # OpenAPI → Dart client + TS contracts
```

## Key structural decisions (write these up as ADRs)

1. **Feature-first Flutter with clean-architecture layers per feature.** Layer-first (`models/`, `screens/`, `services/` at top level) rots at ~15 screens. Feature folders keep blast radius small and map 1:1 to tickets.

2. **Contract-driven API boundary.** The NestJS Swagger decorators generate an OpenAPI spec; `tools/codegen` generates the Dart API client and TS types from it. The mobile app never hand-writes a DTO — this eliminates the #1 source of mobile/backend drift.

3. **PostGIS from day one.** Discovery is a geo product. `ST_DWithin` on a geography column with a GiST index outperforms any hand-rolled geohash approach and gives you distance sorting for free. Redis caches computed decks, Postgres owns truth.

4. **Modular monolith, not microservices.** One NestJS deployable with strict module boundaries. At your scale, microservices buy operational pain and zero benefit. The module layout above lets you extract a service later (chat is the first candidate) without a rewrite.

5. **Jobs queue (BullMQ on Redis) from day one.** Image moderation, push dispatch, and deck precompute must never block request threads.

6. **Flavors in Flutter (dev/staging/prod)** with separate Firebase projects per environment — non-negotiable for safe FCM and analytics.
