# Touch of Cure — API Reference

Base URL: `/api/v1` · Interactive docs: `/api/docs` (Swagger)

Every successful response is wrapped in a consistent envelope:

```json
{ "success": true, "statusCode": 200, "data": { }, "timestamp": "..." }
```

Errors use the same shape with `success: false`, an `error` name and a
`message` that is safe to show the user.

## Authentication

Send the access token as `Authorization: Bearer <token>`. Access tokens live
15 minutes; refresh tokens live 30 days and **rotate on every use**. Presenting
a already-revoked refresh token is treated as theft and revokes the whole
family for that user, forcing a fresh login.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/otp/send` | public | Send a login OTP (5/min per IP) |
| POST | `/auth/otp/verify` | public | Verify OTP, create the account if new |
| POST | `/auth/social` | public | Google or Apple via a Firebase ID token |
| POST | `/auth/login` | public | Password login for therapists and admins |
| POST | `/auth/forgot-password` | public | Send a reset OTP |
| POST | `/auth/reset-password` | public | Reset with OTP, revokes all sessions |
| POST | `/auth/refresh` | public | Rotate tokens |
| POST | `/auth/logout` | user | Revoke the current or all refresh tokens |

## Users

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/users/me` | user | Full profile including the role relation |
| PATCH | `/users/me` | user | Update profile fields |
| POST | `/users/me/avatar` | user | Upload a photo (multipart, max 5 MB) |
| PATCH | `/users/me/password` | user | Change password, revokes all sessions |
| POST | `/users/me/fcm-token` | user | Register a push device |
| DELETE | `/users/me/fcm-token` | user | Unregister a push device |
| DELETE | `/users/me` | user | Deactivate the account (soft delete) |

## Patients

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/patients/me/addresses` | patient | Saved addresses |
| POST | `/patients/me/addresses` | patient | Add an address |
| PATCH | `/patients/me/addresses/:id` | patient | Update an address |
| DELETE | `/patients/me/addresses/:id` | patient | Delete an address |
| GET | `/patients/me/referral` | patient | Referral code and earnings |
| GET | `/patients/my-patients` | therapist | Patients this therapist has treated |
| GET | `/patients/:id/history` | therapist | Clinical history of one of them |

## Therapists

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/therapists` | public | Search with filters, sorting, pagination |
| GET | `/therapists/top-rated` | public | Home screen carousel |
| GET | `/therapists/:id` | public | Full public profile |
| PATCH | `/therapists/me` | therapist | Update own profile and fees |
| PATCH | `/therapists/me/availability-toggle` | therapist | Accept or pause bookings |
| POST | `/therapists/me/certificates` | therapist | Upload a certificate (resets KYC) |
| DELETE | `/therapists/me/certificates/:id` | therapist | Remove a certificate |
| GET | `/therapists/me/bank-details` | therapist | Payout account (number masked) |
| POST | `/therapists/me/bank-details` | therapist | Save account (resets verification) |
| GET | `/therapists/me/reviews` | therapist | Reviews received |

**Search filters:** `search`, `specialization[]`, `minRating`, `minExperience`,
`maxFee`, `isAvailable`, `latitude`, `longitude`, `radiusKm`, `sortBy`,
`sortOrder`, `page`, `limit`. Only KYC-approved, active therapists are ever
returned.

## Availability

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/availability/therapist/:id/slots?date=YYYY-MM-DD` | public | Free 30-minute slots |
| GET | `/availability/me` | therapist | Weekly working windows |
| POST | `/availability/me` | therapist | Add a window (overlaps rejected) |
| PUT | `/availability/me` | therapist | Replace the whole week |
| PATCH | `/availability/me/:slotId` | therapist | Edit a window |
| DELETE | `/availability/me/:slotId` | therapist | Delete a window |

Slots are 30 minutes, bookable up to 60 days ahead, and same-day bookings
require 60 minutes of lead time.

## Appointments

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/appointments` | patient | Book (serializable, prevents double-booking) |
| GET | `/appointments` | user | List scoped to the caller's role |
| GET | `/appointments/today` | therapist | Today's schedule |
| GET | `/appointments/stats` | therapist | Dashboard counters |
| GET | `/appointments/:id` | participant | Detail |
| PATCH | `/appointments/:id/accept` | therapist | Confirm a pending request |
| PATCH | `/appointments/:id/reject` | therapist | Decline with a reason |
| PATCH | `/appointments/:id/cancel` | participant | Cancel with a reason |
| PATCH | `/appointments/:id/reschedule` | patient | Move to another free slot |
| PATCH | `/appointments/:id/start` | therapist | Mark in progress |
| PATCH | `/appointments/:id/complete` | therapist | Mark complete |

Cancelling at least 12 hours before the start returns `refundEligible: true`.

## Payments

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/payments/order` | patient | Create a Razorpay order, or settle from wallet |
| POST | `/payments/verify` | patient | Verify the HMAC signature |
| POST | `/payments/webhook` | public | Razorpay server callback (signature checked) |
| GET | `/payments/:id` | participant | Payment detail |
| GET | `/payments` | admin | All payments with filters |
| POST | `/payments/:id/refund` | admin | Full or partial refund |

Amounts always come from the database, never the request body.

## Wallet and coupons

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/wallet/balance` | user | Current balance |
| GET | `/wallet/transactions` | user | Ledger history |
| POST | `/wallet/referral/apply` | patient | Apply someone's referral code |
| GET | `/wallet/earnings?period=` | therapist | daily / weekly / monthly / yearly |
| GET | `/wallet/payouts` | therapist | Payout history |
| GET | `/coupons/available` | patient | Usable coupons |
| POST | `/coupons/apply` | patient | Preview a discount |
| GET/POST/PATCH/DELETE | `/coupons` | admin | Manage coupons |

## Clinical

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/prescriptions` | therapist | Issue one, generates a PDF |
| PATCH | `/prescriptions/:id` | therapist | Edit, regenerates the PDF |
| GET | `/prescriptions` | user | List scoped to the caller |
| GET | `/prescriptions/:id` | participant | Detail with the PDF link |
| GET | `/exercises` | public | Library with filters |
| GET | `/exercises/categories` | public | Filter chips |
| GET | `/exercises/my-plan` | patient | Assigned plan with progress |
| PATCH | `/exercises/assignments/:id/complete` | patient | Mark done |
| POST | `/exercises/assign` | therapist | Assign a plan |
| POST | `/exercises/upload/video` | therapist/admin | Upload video (max 100 MB) |
| POST | `/progress` | patient | Log a pain level |
| GET | `/progress/chart` | patient | Time series with a trend summary |
| GET | `/progress/patient/:id` | therapist | Chart for one of their patients |

## Reviews, chat and video

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/reviews/therapist/:id` | public | Reviews with a rating histogram |
| GET | `/reviews/pending` | patient | Sessions awaiting a review |
| POST | `/reviews` | patient | Rate a completed appointment (once) |
| GET | `/chat/threads` | user | Conversations with unread counts |
| POST | `/chat/threads` | user | Open or reuse a conversation |
| GET | `/chat/threads/:id/messages` | participant | Paginated history |
| PATCH | `/chat/threads/:id/read` | participant | Mark incoming as read |
| POST | `/video-call/:appointmentId/join` | participant | Agora token (15-min window) |
| POST | `/video-call/:appointmentId/renew-token` | participant | Refresh before expiry |
| POST | `/video-call/:appointmentId/end` | participant | End and record duration |

### Socket.IO — namespace `/chat`

Authenticate during the handshake: `{ auth: { token: accessToken } }`.
Unauthenticated sockets are disconnected immediately.

| Direction | Event | Payload |
|---|---|---|
| emit | `thread:join` | `{ threadId }` |
| emit | `thread:leave` | `{ threadId }` |
| emit | `message:send` | `{ threadId, content, attachmentUrl? }` |
| emit | `typing` | `{ threadId, isTyping }` |
| listen | `message:new` | the created message |
| listen | `message:read` | `{ threadId, readerId }` |
| listen | `typing` | `{ threadId, userId, isTyping }` |
| listen | `user:online` / `user:offline` | `{ userId }` |

## Admin

| Method | Path | Description |
|---|---|---|
| GET | `/admin/dashboard/stats` | KPI cards with month-over-month change |
| GET | `/admin/dashboard/secondary-stats` | Pending payments, unpaid bookings |
| GET | `/admin/dashboard/appointments-overview` | Monthly trend by outcome |
| GET | `/admin/dashboard/revenue-overview` | Monthly captured revenue |
| GET | `/admin/dashboard/appointments-by-type` | Share by type |
| GET | `/admin/dashboard/top-therapists` | Leaderboard |
| GET | `/admin/dashboard/pending-counts` | Sidebar badges |
| GET | `/admin/reports/revenue?fromDate=&toDate=` | Revenue net of refunds |
| GET | `/admin/reports/growth?months=` | Signup and booking growth |
| GET | `/admin/users` | List with role and status filters |
| PATCH | `/admin/users/:id/status` | Block or activate |
| GET | `/admin/kyc` | Verification queue |
| PATCH | `/admin/kyc/:therapistId` | Approve or reject |
| GET | `/admin/payouts/pending` | Amount owed per therapist |
| POST | `/admin/payouts` | Record a payout |
| POST | `/admin/notifications/broadcast` | Push to an audience segment |
| GET/POST/PATCH/DELETE | `/admin/banners`, `/admin/blogs`, `/admin/faqs` | CMS |
| GET/PATCH | `/admin/tickets` | Support queue |
| GET | `/admin/audit-logs` | Audit trail |

## Conventions

**Pagination** — `page` (1-based), `limit` (max 100). Responses return
`{ items, meta: { total, page, limit, totalPages } }`.

**Sorting** — `sortBy` and `sortOrder`. Unknown field names fall back to a safe
default rather than reaching the query.

**Rate limits** — 100 requests/minute globally; OTP endpoints are tighter
(5/minute for send, 10/minute for verify). Nginx also throttles at the edge.

**Security** — Helmet headers, strict CORS allow-list, whitelisted DTO
validation (unknown properties are stripped, blocking mass assignment),
bcrypt cost 12, refresh tokens stored as SHA-256 digests, and an audit log for
every state-changing request with secrets redacted.
