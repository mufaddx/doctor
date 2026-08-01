import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** Merges Tailwind classes, letting later conditional classes win. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** Indian numbering with the rupee symbol, e.g. ₹8,45,230. */
export function formatCurrency(value: number | string): string {
  const amount = typeof value === 'string' ? parseFloat(value) : value;
  if (Number.isNaN(amount)) return '₹0';

  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(amount);
}

export function formatNumber(value: number): string {
  return new Intl.NumberFormat('en-IN').format(value);
}

/** Compact axis labels: 8L for 800000, 12K for 12000. */
export function formatCompact(value: number): string {
  if (value >= 10_000_000) return `${(value / 10_000_000).toFixed(1)}Cr`;
  if (value >= 100_000) return `${(value / 100_000).toFixed(0)}L`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(0)}K`;
  return value.toString();
}

/** Converts a "2026-08" bucket key into "Aug". */
export function monthLabel(key: string): string {
  const [year, month] = key.split('-').map(Number);
  return new Date(year, month - 1).toLocaleString('en-US', { month: 'short' });
}

export function readableType(type: string): string {
  return {
    CLINIC_VISIT: 'Clinic Visit',
    HOME_VISIT: 'Home Visit',
    VIDEO_CONSULTATION: 'Video Call',
  }[type] ?? type;
}

export function readableStatus(status: string): string {
  return {
    PENDING: 'Pending',
    CONFIRMED: 'Confirmed',
    IN_PROGRESS: 'In Progress',
    COMPLETED: 'Completed',
    CANCELLED: 'Cancelled',
    REJECTED: 'Declined',
    NO_SHOW: 'No Show',
  }[status] ?? status;
}

/** Tailwind classes for the coloured status pills used across tables. */
export function statusClasses(status: string): string {
  switch (status) {
    case 'COMPLETED':
    case 'PAID':
    case 'APPROVED':
    case 'RESOLVED':
      return 'bg-emerald-50 text-emerald-700 ring-emerald-200';
    case 'CONFIRMED':
    case 'IN_PROGRESS':
      return 'bg-blue-50 text-blue-700 ring-blue-200';
    case 'PENDING':
    case 'OPEN':
      return 'bg-amber-50 text-amber-700 ring-amber-200';
    case 'CANCELLED':
    case 'REJECTED':
    case 'FAILED':
      return 'bg-rose-50 text-rose-700 ring-rose-200';
    case 'REFUNDED':
    case 'PARTIALLY_REFUNDED':
      return 'bg-purple-50 text-purple-700 ring-purple-200';
    default:
      return 'bg-slate-100 text-slate-700 ring-slate-200';
  }
}

/** Deterministic avatar colour so the same person keeps the same swatch. */
export function avatarColor(name: string): string {
  const palette = [
    'bg-teal-600',
    'bg-violet-600',
    'bg-rose-600',
    'bg-blue-600',
    'bg-orange-600',
  ];
  const hash = name.split('').reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return palette[hash % palette.length];
}

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return `${parts[0].charAt(0)}${parts[parts.length - 1].charAt(0)}`.toUpperCase();
}
