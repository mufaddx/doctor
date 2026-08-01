# Touch of Cure — Setup Guide

Physiotherapy platform: NestJS API, PostgreSQL, Redis, two Flutter apps and a
Next.js admin panel.

---

## 1. Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| Node.js | 22 LTS | Backend, admin panel |
| Docker + Compose | latest | Postgres, Redis, full stack |
| Flutter | 3.24+ (Dart 3.5+) | Both mobile apps |
| PostgreSQL | 16 | Database (or use Docker) |
| Redis | 7 | Cache (or use Docker) |

You will also need accounts for **Firebase**, **Razorpay**, **Agora** and an SMS
provider (**MSG91** is wired in, but any provider works — see `sms.service.ts`).

---

## 2. Third-party setup

### Firebase (auth, storage, push)
1. Create a project at console.firebase.google.com.
2. Enable **Authentication** → Google and Apple sign-in providers.
3. Enable **Cloud Storage** and note the bucket name.
4. Project Settings → Service Accounts → **Generate new private key**. The JSON
   gives you `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL` and
   `FIREBASE_PRIVATE_KEY`.
5. Register an Android app (`com.touchofcure.patient` and
   `com.touchofcure.therapist`) and an iOS app, then download
   `google-services.json` / `GoogleService-Info.plist` into each Flutter app.
6. Generate `firebase_options.dart` in each app:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### Razorpay (payments)
1. Get the test key id and secret from the dashboard.
2. Add a webhook pointing at `https://<your-api>/api/v1/payments/webhook` and
   subscribe to `payment.captured` and `payment.failed`.
3. Copy the webhook secret into `RAZORPAY_WEBHOOK_SECRET`.

The webhook is the source of truth for payment state — the client callback can
be lost if the app is killed mid-checkout, so never rely on it alone.

### Agora (video consultation)
1. Create a project in **secured mode** (App ID + Certificate).
2. Both values go into the backend env. The apps receive short-lived tokens
   from the API and never hold the certificate.

---

## 3. Backend

```bash
cd backend
cp .env.example .env      # then fill in every value
npm install
```

Generate strong JWT secrets (do not reuse the same value for both):

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

Start Postgres and Redis, run migrations, seed reference data:

```bash
docker compose up -d postgres redis

npx prisma migrate dev --name init
npx prisma generate

# The seed refuses to run without an explicit admin password
SEED_ADMIN_PASSWORD='ChangeThis@123' npm run prisma:seed

npm run start:dev
```

- API: `http://localhost:3000/api/v1`
- Swagger: `http://localhost:3000/api/docs`
- Health: `http://localhost:3000/api/v1/health`

The seed creates the super admin (phone `9999999999` by default), the global
exercise library, help-centre FAQs and two launch coupons.

---

## 4. Admin panel

```bash
cd admin-panel
npm install

echo 'NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1' > .env.local
npm run dev
```

Open `http://localhost:3001` and sign in with the seeded admin credentials.
Only `ADMIN` and `SUPER_ADMIN` accounts can enter — a valid patient login is
rejected at the store level.

---

## 5. Flutter apps

Configuration is passed with `--dart-define` so no key is baked into the
repository.

### Patient app
```bash
cd patient-app
flutter pub get

flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx \
  --dart-define=AGORA_APP_ID=xxx \
  --dart-define=GOOGLE_MAPS_API_KEY=xxx
```

### Therapist app
```bash
cd therapist-app
flutter pub get

flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=AGORA_APP_ID=xxx
```

`10.0.2.2` is how the Android emulator reaches the host machine. On an iOS
simulator use `localhost`; on a physical device use your machine's LAN IP.

### Release builds
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.touchofcure.in/api/v1 ...
flutter build ipa --release --dart-define=...
```

---

## 6. Required platform permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**iOS** (`ios/Runner/Info.plist`): add usage descriptions for
`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
`NSLocationWhenInUseUsageDescription` and `NSPhotoLibraryUsageDescription`.
Missing any of these causes a silent crash on first use, not a prompt.

---

## 7. Full stack with Docker

```bash
# Root .env supplies POSTGRES_PASSWORD and NEXT_PUBLIC_API_URL
docker compose up -d --build
```

Brings up Postgres, Redis, the API (migrations run on boot), the admin panel
and Nginx. For TLS, place `fullchain.pem` and `privkey.pem` in `nginx/certs/`.

---

## 8. Testing

```bash
cd backend && npm test && npm run test:e2e
cd patient-app && flutter test
cd therapist-app && flutter test
cd admin-panel && npx tsc --noEmit && npm run lint
```

CI runs all of this on every push to `main` and `develop`, then builds and
pushes Docker images plus signed Android bundles.

---

## 9. Common issues

**`Invalid environment configuration` on boot** — env validation fails fast by
design. The error names every missing variable; fill them in `.env`.

**Flutter app cannot reach the API** — check the host address for your target
(emulator vs simulator vs device) and that the backend is bound to `0.0.0.0`.

**Payments succeed but bookings stay unpaid** — the webhook is not reaching
your machine. Use a tunnel (`ngrok http 3000`) and point the Razorpay webhook
at the public URL during development.

**Video call fails to connect** — the Agora project must be in secured mode and
the App Certificate must match. Also confirm camera and mic permissions were
actually granted rather than dismissed.

**Therapist receives no bookings** — an unverified therapist is invisible in
patient search by design. Approve them from the admin panel's KYC queue.
