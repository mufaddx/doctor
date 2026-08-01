# Touch of Cure — Monorepo Structure

```
touch-of-cure/
├── backend/                          # NestJS API
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   └── seed.ts
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   ├── common/
│   │   │   ├── decorators/           # @CurrentUser, @Roles, @Public
│   │   │   ├── guards/                # JwtAuthGuard, RolesGuard, RefreshGuard
│   │   │   ├── interceptors/          # Logging, Transform, Timeout
│   │   │   ├── filters/               # HttpExceptionFilter
│   │   │   ├── middleware/            # RateLimiter, AuditLog
│   │   │   ├── pipes/                 # ValidationPipe config
│   │   │   └── utils/                 # pagination.util.ts, hash.util.ts
│   │   ├── config/                    # env validation, config modules
│   │   ├── modules/
│   │   │   ├── auth/                  # OTP, Google, Apple, JWT, Refresh
│   │   │   ├── users/
│   │   │   ├── patients/
│   │   │   ├── therapists/
│   │   │   ├── appointments/
│   │   │   ├── availability/
│   │   │   ├── payments/              # Razorpay
│   │   │   ├── wallet/
│   │   │   ├── coupons/
│   │   │   ├── prescriptions/
│   │   │   ├── exercises/
│   │   │   ├── progress/
│   │   │   ├── reviews/
│   │   │   ├── chat/                  # Socket.IO gateway
│   │   │   ├── video-call/            # Agora token service
│   │   │   ├── notifications/         # FCM
│   │   │   ├── uploads/               # Firebase Storage
│   │   │   ├── admin/
│   │   │   │   ├── analytics/
│   │   │   │   ├── kyc/
│   │   │   │   ├── cms/
│   │   │   │   ├── banners/
│   │   │   │   ├── reports/
│   │   │   │   └── support-tickets/
│   │   │   └── blogs-faqs/
│   │   └── database/
│   │       └── prisma.service.ts
│   ├── test/
│   ├── docker/
│   │   ├── Dockerfile
│   │   └── docker-compose.yml
│   ├── .env.example
│   ├── nest-cli.json
│   ├── tsconfig.json
│   └── package.json
│
├── patient-app/                       # Flutter
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── router/                # go_router
│       │   ├── theme/                 # MD3 theme, dark mode
│       │   ├── network/               # dio client, interceptors
│       │   ├── constants/
│       │   └── widgets/               # shared reusable widgets
│       ├── features/
│       │   ├── auth/
│       │   │   ├── data/
│       │   │   ├── domain/
│       │   │   └── presentation/ (screens, providers/riverpod)
│       │   ├── onboarding/
│       │   ├── home/
│       │   ├── search/
│       │   ├── therapist_profile/
│       │   ├── booking/
│       │   ├── payment/
│       │   ├── appointments/
│       │   ├── prescription/
│       │   ├── exercises/
│       │   ├── progress/
│       │   ├── chat/
│       │   ├── video_call/
│       │   ├── wallet/
│       │   ├── notifications/
│       │   ├── referral/
│       │   ├── profile/
│       │   └── settings/
│       └── l10n/
│
├── therapist-app/                     # Flutter (mirrors patient-app structure)
│   └── lib/
│       ├── main.dart
│       ├── core/
│       └── features/
│           ├── auth/
│           ├── dashboard/
│           ├── appointments/
│           ├── availability/
│           ├── video_call/
│           ├── patients/
│           ├── prescription/
│           ├── exercise_assignment/
│           ├── chat/
│           ├── wallet/
│           ├── reviews/
│           └── settings/
│
├── admin-panel/                       # Next.js + Tailwind
│   └── src/
│       ├── app/
│       │   ├── (auth)/login/
│       │   └── (dashboard)/
│       │       ├── dashboard/
│       │       ├── users/
│       │       ├── therapists/
│       │       ├── patients/
│       │       ├── appointments/
│       │       ├── payments/ refunds/ payouts/
│       │       ├── kyc/
│       │       ├── exercises/
│       │       ├── coupons/
│       │       ├── notifications/
│       │       ├── cms/ banners/
│       │       ├── reports/
│       │       ├── support-tickets/
│       │       └── settings/
│       ├── components/
│       ├── lib/                       # api client, auth
│       └── store/
│
├── docs/
│   ├── 01-FOLDER-STRUCTURE.md
│   ├── 02-DATABASE-SCHEMA.md
│   ├── 03-API-SPEC.md
│   ├── 04-SETUP-GUIDE.md
│   └── 05-DEPLOYMENT.md
│
├── .github/workflows/                 # CI/CD
│   ├── backend-ci.yml
│   ├── admin-ci.yml
│   └── flutter-ci.yml
│
└── docker-compose.yml                 # postgres, redis, backend, admin
```

**Architecture pattern (backend):** each module = `controller` → `service` → `repository (Prisma)`, with its own `dto/`, `entities/`, and `guards/` where needed. Strict separation: controllers never touch Prisma directly.

**Architecture pattern (Flutter):** feature-first, each feature split into `data` (models, repositories, API), `domain` (entities, use-cases where needed), `presentation` (screens, widgets, Riverpod providers/notifiers).
