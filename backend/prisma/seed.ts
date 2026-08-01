import { CouponType, KycStatus, PrismaClient, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

/**
 * Seeds the reference data the platform needs to run: the super admin
 * account, the global exercise library, help-centre FAQs and launch coupons.
 * It is idempotent, so it is safe to run on every deploy.
 */
async function main() {
  console.log('Seeding Touch of Cure database...');

  // ---------------- Super admin ----------------
  const adminPhone = process.env.SEED_ADMIN_PHONE ?? '9999999999';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;

  if (!adminPassword) {
    throw new Error(
      'SEED_ADMIN_PASSWORD must be set. Never ship a hard-coded admin password.',
    );
  }

  const admin = await prisma.user.upsert({
    where: { phone: adminPhone },
    update: {},
    create: {
      phone: adminPhone,
      fullName: 'Platform Administrator',
      email: process.env.SEED_ADMIN_EMAIL ?? 'admin@touchofcure.in',
      role: UserRole.SUPER_ADMIN,
      isVerified: true,
      passwordHash: await bcrypt.hash(adminPassword, 12),
      admin: { create: { isSuper: true, permissions: ['*'] } },
      wallet: { create: {} },
    },
  });
  console.log(`Super admin ready: ${admin.phone}`);

  // ---------------- Global exercise library ----------------
  const exercises = [
    {
      title: 'Lower Back Stretch',
      category: 'Back Pain',
      level: 'Beginner',
      durationMinutes: 10,
      instructions: [
        'Lie down on your back on a flat surface.',
        'Bend your knees and bring them towards your chest.',
        'Hold the position for 10 seconds and release slowly.',
      ],
    },
    {
      title: 'Cat Camel Stretch',
      category: 'Back Pain',
      level: 'Beginner',
      durationMinutes: 8,
      instructions: [
        'Start on your hands and knees.',
        'Arch your back upward, then let it sag downward.',
        'Move slowly between the two positions.',
      ],
    },
    {
      title: 'Bridging',
      category: 'Back Pain',
      level: 'Intermediate',
      durationMinutes: 10,
      instructions: [
        'Lie on your back with knees bent and feet flat.',
        'Lift your hips until your body forms a straight line.',
        'Hold briefly and lower with control.',
      ],
    },
    {
      title: 'Neck Stretch',
      category: 'Neck Pain',
      level: 'Beginner',
      durationMinutes: 8,
      instructions: [
        'Sit upright with shoulders relaxed.',
        'Tilt your head slowly towards one shoulder.',
        'Hold for 15 seconds and repeat on the other side.',
      ],
    },
    {
      title: 'Shoulder Rotation',
      category: 'Shoulder',
      level: 'Beginner',
      durationMinutes: 6,
      instructions: [
        'Stand with arms relaxed at your sides.',
        'Roll your shoulders forward in slow circles.',
        'Reverse the direction after ten rotations.',
      ],
    },
    {
      title: 'Knee Strengthening',
      category: 'Knee',
      level: 'Intermediate',
      durationMinutes: 12,
      instructions: [
        'Sit on a chair with your back straight.',
        'Straighten one leg out in front of you.',
        'Hold for five seconds, then lower slowly.',
      ],
    },
    {
      title: 'Child Pose',
      category: 'Back Pain',
      level: 'Beginner',
      durationMinutes: 5,
      instructions: [
        'Kneel and sit back on your heels.',
        'Fold forward and stretch your arms ahead.',
        'Breathe deeply and hold the position.',
      ],
    },
  ];

  for (const exercise of exercises) {
    const existing = await prisma.exercise.findFirst({
      where: { title: exercise.title, isGlobal: true },
    });
    if (existing) continue;

    await prisma.exercise.create({
      data: {
        ...exercise,
        isGlobal: true,
        // Media is uploaded through the admin panel after deployment
        videoUrl: `${process.env.SEED_MEDIA_BASE_URL ?? 'https://storage.touchofcure.in/exercises'}/${slugify(exercise.title)}.mp4`,
        thumbnailUrl: `${process.env.SEED_MEDIA_BASE_URL ?? 'https://storage.touchofcure.in/exercises'}/${slugify(exercise.title)}.jpg`,
      },
    });
  }
  console.log(`Exercise library seeded (${exercises.length} entries)`);

  // ---------------- FAQs ----------------
  const faqs = [
    {
      question: 'How do I book a physiotherapy session?',
      answer:
        'Search for a therapist, open their profile, pick an available slot and choose clinic visit, home visit or video consultation. Confirm the payment to complete the booking.',
      category: 'Booking',
      sortOrder: 1,
    },
    {
      question: 'Can I cancel or reschedule my appointment?',
      answer:
        'Yes. Cancelling at least 12 hours before the scheduled time makes you eligible for a full refund. You can also move a booking to any other free slot with the same therapist.',
      category: 'Booking',
      sortOrder: 2,
    },
    {
      question: 'How long do refunds take?',
      answer:
        'Refunds to the original payment method usually reflect within 5 to 7 working days. Wallet refunds are credited instantly.',
      category: 'Payments',
      sortOrder: 3,
    },
    {
      question: 'Are the therapists verified?',
      answer:
        'Every therapist on the platform submits their qualification certificates, which our team reviews before their profile becomes visible to patients.',
      category: 'General',
      sortOrder: 4,
    },
    {
      question: 'How does the referral programme work?',
      answer:
        'Share your referral code from the Refer & Earn screen. When a new patient applies your code, the bonus is credited straight to your wallet.',
      category: 'General',
      sortOrder: 5,
    },
  ];

  for (const faq of faqs) {
    const existing = await prisma.faq.findFirst({ where: { question: faq.question } });
    if (!existing) await prisma.faq.create({ data: faq });
  }
  console.log(`FAQs seeded (${faqs.length} entries)`);

  // ---------------- Launch coupons ----------------
  const now = new Date();
  const yearEnd = new Date(now.getFullYear(), 11, 31, 23, 59, 59);

  await prisma.coupon.upsert({
    where: { code: 'TOC30' },
    update: {},
    create: {
      code: 'TOC30',
      type: CouponType.PERCENTAGE,
      value: 30,
      maxDiscount: 150,
      minOrderValue: 300,
      usageLimit: 1000,
      validFrom: now,
      validUntil: yearEnd,
    },
  });

  await prisma.coupon.upsert({
    where: { code: 'FIRST100' },
    update: {},
    create: {
      code: 'FIRST100',
      type: CouponType.FLAT,
      value: 100,
      minOrderValue: 400,
      usageLimit: 5000,
      validFrom: now,
      validUntil: yearEnd,
    },
  });
  console.log('Launch coupons seeded');

  console.log('Seeding complete.');
}

function slugify(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

main()
  .catch((error) => {
    console.error('Seeding failed:', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
