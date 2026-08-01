# Touch of Cure

Physiotherapy healthcare platform — patient app, therapist app, admin panel and API.

```
touch-of-cure/
├── backend/          NestJS + Prisma + PostgreSQL + Redis  (90 files)
├── patient-app/      Flutter + Riverpod + Go Router        (62 files)
├── therapist-app/    Flutter + Riverpod + Go Router        (48 files)
├── admin-panel/      Next.js 15 + TailwindCSS              (29 files)
├── nginx/            TLS termination, rate limiting, WS upgrade
├── docs/             Setup guide, API reference, schema notes
├── .github/workflows CI/CD for all four projects
└── docker-compose.yml
```

## Quick start

```bash
# 1. Database and cache
docker compose up -d postgres redis

# 2. Backend
cd backend
cp .env.example .env            # fill in every value
npm install
npx prisma migrate dev --name init
SEED_ADMIN_PASSWORD='ChangeThis@123' npm run prisma:seed
npm run start:dev               # http://localhost:3000/api/docs

# 3. Admin panel
cd ../admin-panel
npm install
echo 'NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1' > .env.local
npm run dev                     # http://localhost:3001

# 4. Mobile apps
cd ../patient-app && flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 ...
```

Full instructions, third-party account setup and troubleshooting:
**`docs/04-SETUP-GUIDE.md`**

## What is implemented

**Backend** — OTP/Google/Apple auth with refresh-token rotation and reuse
detection, role-based access control, therapist search with geo filtering,
slot generation and race-safe booking, Razorpay payments with webhook
verification and refunds, wallet ledger, prescriptions with PDF generation,
exercise library and assignment, progress tracking with trend analysis,
Socket.IO chat, Agora video tokens, FCM push, admin analytics, KYC queue,
payouts, CMS, support tickets and audit logging.

**Patient app** — onboarding, OTP and social login, therapist search with
filters, booking flow (calendar → slot → type → summary → payment), Razorpay
checkout, appointments, prescriptions, exercise plan, progress charts, chat,
video consultation, wallet, referrals, notifications, profile and settings.

**Therapist app** — dashboard with availability toggle, appointment accept and
reject, weekly availability editor, patient records, prescription writer,
exercise assignment, earnings with payout history, reviews and bank details.

**Admin panel** — dashboard with KPIs and charts, user management, KYC
verification, payouts, coupons, support tickets, and CMS.

## Before going live

This is a complete, working foundation rather than a shipped product. Before
handling real patient data you still need to:

- Run end-to-end integration testing against real Firebase, Razorpay and Agora
  credentials in a staging environment.
- Complete the remaining secondary screens (settings variants, the in-app
  forgot-password flow) following the existing patterns.
- Have the data handling reviewed against the health-data regulations that
  apply in your jurisdiction, and put a backup and retention policy in place.
- Load test the booking and payment paths, which are the race-sensitive ones.
