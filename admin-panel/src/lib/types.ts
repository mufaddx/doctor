export type UserRole = 'PATIENT' | 'THERAPIST' | 'ADMIN' | 'SUPER_ADMIN';
export type KycStatus = 'NOT_SUBMITTED' | 'PENDING' | 'APPROVED' | 'REJECTED';
export type AppointmentStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'CANCELLED'
  | 'REJECTED'
  | 'NO_SHOW';
export type AppointmentType =
  | 'CLINIC_VISIT'
  | 'HOME_VISIT'
  | 'VIDEO_CONSULTATION';
export type PaymentStatus =
  | 'PENDING'
  | 'PAID'
  | 'FAILED'
  | 'REFUNDED'
  | 'PARTIALLY_REFUNDED';
export type TicketStatus = 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED';

export interface AdminUser {
  id: string;
  fullName: string;
  email: string | null;
  phone: string;
  role: UserRole;
  avatarUrl: string | null;
  isActive: boolean;
  isVerified: boolean;
  createdAt: string;
  therapist?: { id: string; kycStatus: KycStatus; ratingAvg: number } | null;
  patient?: { id: string } | null;
}

/** Each KPI carries its own month-over-month delta. */
export interface StatMetric {
  value: number;
  changePercent: number;
}

export interface DashboardStats {
  totalUsers: StatMetric;
  therapists: StatMetric;
  patients: StatMetric;
  totalAppointments: StatMetric;
  totalRevenue: StatMetric;
}

export interface SecondaryStats {
  pendingPayments: { count: number; amount: number };
  unpaidAppointments: { count: number; amount: number };
  therapistsOnLeave: number;
  activeOffers: number;
}

export interface AppointmentOverviewPoint {
  month: string;
  completed: number;
  upcoming: number;
  cancelled: number;
}

export interface RevenueOverview {
  series: { month: string; revenue: number }[];
  total: number;
}

export interface AppointmentTypeShare {
  type: AppointmentType;
  count: number;
  percentage: number;
}

export interface TopTherapist {
  id: string;
  fullName: string;
  avatarUrl: string | null;
  rating: number;
  appointmentCount: number;
}

export interface LatestAppointment {
  id: string;
  type: AppointmentType;
  status: AppointmentStatus;
  scheduledDate: string;
  startTime: string;
  totalAmount: string;
  patient: { user: { fullName: string; avatarUrl: string | null } };
  therapist: { user: { fullName: string } };
  payment: { status: PaymentStatus } | null;
}

export interface RecentReview {
  id: string;
  rating: number;
  comment: string | null;
  createdAt: string;
  author: { fullName: string; avatarUrl: string | null };
  therapist: { user: { fullName: string } };
}

export interface PendingCounts {
  pendingKyc: number;
  openTickets: number;
  pendingRefunds: number;
  pendingPayouts: number;
}

export interface KycCandidate {
  id: string;
  specialization: string[];
  experienceYears: number;
  kycStatus: KycStatus;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone: string;
    email: string | null;
    avatarUrl: string | null;
  };
  certificates: { id: string; title: string; fileUrl: string; verified: boolean }[];
  bankDetail: { bankName: string; ifscCode: string; verified: boolean } | null;
}

export interface PendingPayout {
  therapistId: string;
  fullName: string;
  avatarUrl: string | null;
  bankVerified: boolean;
  bankName: string | null;
  totalEarned: number;
  alreadyPaid: number;
  pendingAmount: number;
}

export interface SupportTicket {
  id: string;
  subject: string;
  message: string;
  status: TicketStatus;
  createdAt: string;
  user: {
    id: string;
    fullName: string;
    phone: string;
    role: UserRole;
    avatarUrl: string | null;
  };
}

export interface Coupon {
  id: string;
  code: string;
  type: 'PERCENTAGE' | 'FLAT';
  value: string;
  maxDiscount: string | null;
  minOrderValue: string | null;
  usageLimit: number | null;
  usedCount: number;
  validFrom: string;
  validUntil: string;
  isActive: boolean;
  _count?: { redemptions: number };
}
