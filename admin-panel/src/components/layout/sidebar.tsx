'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  BadgeCheck,
  Banknote,
  BarChart3,
  Bell,
  Calendar,
  ChevronLeft,
  CreditCard,
  FileText,
  Image as ImageIcon,
  LayoutDashboard,
  LifeBuoy,
  MessageSquare,
  Percent,
  RefreshCcw,
  Settings,
  Star,
  Stethoscope,
  Users,
  Wallet,
} from 'lucide-react';

import { api } from '@/lib/api-client';
import type { PendingCounts } from '@/lib/types';
import { cn } from '@/lib/utils';

interface NavItem {
  label: string;
  href: string;
  icon: React.ElementType;
  /** Which pending counter, if any, drives this item's badge. */
  badgeKey?: keyof PendingCounts;
}

interface NavSection {
  title: string | null;
  items: NavItem[];
}

const NAV_SECTIONS: NavSection[] = [
  {
    title: null,
    items: [
      { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
    ],
  },
  {
    title: 'Management',
    items: [
      { label: 'Users', href: '/users', icon: Users },
      { label: 'Therapists', href: '/therapists', icon: Stethoscope },
      { label: 'Patients', href: '/patients', icon: Users },
      { label: 'Appointments', href: '/appointments', icon: Calendar },
      { label: 'Exercises', href: '/exercises', icon: BarChart3 },
      { label: 'Reviews', href: '/reviews', icon: Star },
      {
        label: 'KYC Verification',
        href: '/kyc',
        icon: BadgeCheck,
        badgeKey: 'pendingKyc',
      },
    ],
  },
  {
    title: 'Communication',
    items: [
      { label: 'Notifications', href: '/notifications', icon: Bell },
      {
        label: 'Support Tickets',
        href: '/tickets',
        icon: LifeBuoy,
        badgeKey: 'openTickets',
      },
    ],
  },
  {
    title: 'Finance',
    items: [
      { label: 'Payments', href: '/payments', icon: CreditCard },
      {
        label: 'Refunds',
        href: '/refunds',
        icon: RefreshCcw,
        badgeKey: 'pendingRefunds',
      },
      {
        label: 'Payouts',
        href: '/payouts',
        icon: Banknote,
        badgeKey: 'pendingPayouts',
      },
      { label: 'Coupons', href: '/coupons', icon: Percent },
    ],
  },
  {
    title: 'Other',
    items: [
      { label: 'CMS / Blogs', href: '/cms', icon: FileText },
      { label: 'Banners', href: '/banners', icon: ImageIcon },
      { label: 'Reports', href: '/reports', icon: BarChart3 },
      { label: 'Audit Logs', href: '/audit-logs', icon: MessageSquare },
      { label: 'Settings', href: '/settings', icon: Settings },
    ],
  },
];

export function Sidebar({
  collapsed,
  onToggle,
}: {
  collapsed: boolean;
  onToggle: () => void;
}) {
  const pathname = usePathname();

  // Badges refresh on an interval so the queue counts stay roughly live
  const { data: counts } = useQuery({
    queryKey: ['pending-counts'],
    queryFn: () => api.get<PendingCounts>('/admin/dashboard/pending-counts'),
    refetchInterval: 60_000,
  });

  return (
    <aside
      className={cn(
        'fixed inset-y-0 left-0 z-40 flex flex-col bg-sidebar transition-all duration-200',
        collapsed ? 'w-[72px]' : 'w-64',
      )}
    >
      <div className="flex h-16 items-center gap-3 px-5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-600">
          <Wallet className="h-5 w-5 text-white" />
        </div>
        {!collapsed && (
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-white">
              Touch of Cure
            </p>
            <p className="text-[11px] text-sidebar-muted">Admin Panel</p>
          </div>
        )}
      </div>

      <nav className="flex-1 space-y-6 overflow-y-auto px-3 py-4">
        {NAV_SECTIONS.map((section, sectionIndex) => (
          <div key={section.title ?? `section-${sectionIndex}`}>
            {section.title && !collapsed && (
              <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-wider text-sidebar-muted">
                {section.title}
              </p>
            )}

            <ul className="space-y-1">
              {section.items.map((item) => {
                // Prefix match keeps the parent highlighted on detail pages
                const active =
                  pathname === item.href || pathname.startsWith(`${item.href}/`);
                const badge = item.badgeKey ? counts?.[item.badgeKey] : undefined;

                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      title={collapsed ? item.label : undefined}
                      className={cn(
                        'group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors',
                        active
                          ? 'bg-brand-600 font-medium text-white'
                          : 'text-slate-300 hover:bg-sidebar-hover hover:text-white',
                      )}
                    >
                      <item.icon className="h-[18px] w-[18px] shrink-0" />

                      {!collapsed && (
                        <>
                          <span className="flex-1 truncate">{item.label}</span>
                          {badge !== undefined && badge > 0 && (
                            <span className="rounded-full bg-rose-500 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                              {badge > 99 ? '99+' : badge}
                            </span>
                          )}
                        </>
                      )}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      <button
        onClick={onToggle}
        className="m-3 flex items-center justify-center gap-2 rounded-lg border border-slate-700 py-2.5 text-sm text-slate-300 transition-colors hover:bg-sidebar-hover hover:text-white"
      >
        <ChevronLeft
          className={cn(
            'h-4 w-4 transition-transform',
            collapsed && 'rotate-180',
          )}
        />
        {!collapsed && <span>Collapse Menu</span>}
      </button>
    </aside>
  );
}
