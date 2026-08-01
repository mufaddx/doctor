'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

import { Sidebar } from '@/components/layout/sidebar';
import { Topbar } from '@/components/layout/topbar';
import { useAuthStore } from '@/lib/auth-store';
import { cn } from '@/lib/utils';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const { status, restoreSession } = useAuthStore();
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    if (status === 'unknown') restoreSession();
  }, [status, restoreSession]);

  useEffect(() => {
    if (status === 'unauthenticated') router.replace('/login');
  }, [status, router]);

  // Holding here avoids a flash of the dashboard before the redirect lands
  if (status !== 'authenticated') {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      <Sidebar collapsed={collapsed} onToggle={() => setCollapsed((v) => !v)} />

      <div
        className={cn(
          'transition-all duration-200',
          collapsed ? 'lg:pl-[72px]' : 'lg:pl-64',
        )}
      >
        <Topbar onMenuClick={() => setCollapsed((v) => !v)} />
        <main className="p-6">{children}</main>
      </div>
    </div>
  );
}
