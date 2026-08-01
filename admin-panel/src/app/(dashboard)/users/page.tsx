'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import { Ban, CheckCircle2 } from 'lucide-react';
import { toast } from 'sonner';

import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Column, DataTable } from '@/components/ui/data-table';
import { api, PaginatedResponse } from '@/lib/api-client';
import type { AdminUser, UserRole } from '@/lib/types';
import { cn } from '@/lib/utils';

const ROLE_FILTERS: { label: string; value: UserRole | 'ALL' }[] = [
  { label: 'All', value: 'ALL' },
  { label: 'Patients', value: 'PATIENT' },
  { label: 'Therapists', value: 'THERAPIST' },
  { label: 'Admins', value: 'ADMIN' },
];

export default function UsersPage() {
  const queryClient = useQueryClient();

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [role, setRole] = useState<UserRole | 'ALL'>('ALL');
  const [sortBy, setSortBy] = useState('createdAt');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['admin-users', page, search, role, sortBy, sortOrder],
    queryFn: () =>
      api.get<PaginatedResponse<AdminUser>>('/admin/users', {
        page,
        limit: 20,
        sortBy,
        sortOrder,
        ...(search ? { search } : {}),
        ...(role !== 'ALL' ? { role } : {}),
      }),
  });

  const toggleStatus = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      api.patch(`/admin/users/${id}/status`, { isActive }),
    onSuccess: (_, variables) => {
      // Invalidating the list is enough; the row re-renders with fresh data
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
      toast.success(
        variables.isActive ? 'User activated' : 'User deactivated',
      );
    },
    onError: (mutationError: Error) => toast.error(mutationError.message),
  });

  const columns: Column<AdminUser>[] = [
    {
      key: 'fullName',
      header: 'User',
      sortable: true,
      render: (user) => (
        <div className="flex items-center gap-3">
          <Avatar src={user.avatarUrl} name={user.fullName} size={34} />
          <div className="min-w-0">
            <p className="truncate font-medium text-slate-900">
              {user.fullName}
            </p>
            <p className="truncate text-xs text-slate-500">
              {user.email ?? `+91 ${user.phone}`}
            </p>
          </div>
        </div>
      ),
    },
    {
      key: 'phone',
      header: 'Phone',
      render: (user) => (
        <span className="text-slate-600">+91 {user.phone}</span>
      ),
    },
    {
      key: 'role',
      header: 'Role',
      sortable: true,
      render: (user) => (
        <span className="rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-700">
          {user.role.replace('_', ' ')}
        </span>
      ),
    },
    {
      key: 'kyc',
      header: 'Verification',
      render: (user) =>
        // Only therapists go through KYC, so other roles show a dash
        user.therapist ? (
          <Badge status={user.therapist.kycStatus} />
        ) : (
          <span className="text-slate-400">—</span>
        ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (user) => (
        <Badge
          status={user.isActive ? 'APPROVED' : 'REJECTED'}
          label={user.isActive ? 'Active' : 'Blocked'}
        />
      ),
    },
    {
      key: 'createdAt',
      header: 'Joined',
      sortable: true,
      render: (user) => (
        <span className="whitespace-nowrap text-slate-600">
          {format(new Date(user.createdAt), 'd MMM yyyy')}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      align: 'right',
      render: (user) => (
        <button
          disabled={
            toggleStatus.isPending || user.role === 'SUPER_ADMIN'
          }
          onClick={() =>
            toggleStatus.mutate({ id: user.id, isActive: !user.isActive })
          }
          title={
            user.role === 'SUPER_ADMIN'
              ? 'A super admin cannot be blocked'
              : undefined
          }
          className={cn(
            'inline-flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition disabled:opacity-40',
            user.isActive
              ? 'border-rose-200 text-rose-600 hover:bg-rose-50'
              : 'border-emerald-200 text-emerald-600 hover:bg-emerald-50',
          )}
        >
          {user.isActive ? (
            <>
              <Ban className="h-3.5 w-3.5" />
              Block
            </>
          ) : (
            <>
              <CheckCircle2 className="h-3.5 w-3.5" />
              Activate
            </>
          )}
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Users</h1>
        <p className="mt-1 text-sm text-slate-500">
          Every account on the platform
        </p>
      </div>

      <DataTable
        columns={columns}
        rows={data?.items}
        rowKey={(user) => user.id}
        isLoading={isLoading}
        error={error as Error | null}
        onRetry={refetch}
        emptyTitle="No users found"
        emptyMessage="Try a different search term or filter."
        searchValue={search}
        onSearchChange={(value) => {
          setSearch(value);
          // A new search must start from the first page
          setPage(1);
        }}
        searchPlaceholder="Search by name, email or phone"
        sortBy={sortBy}
        sortOrder={sortOrder}
        onSortChange={(key, order) => {
          setSortBy(key);
          setSortOrder(order);
        }}
        page={page}
        totalPages={data?.meta.totalPages ?? 1}
        total={data?.meta.total ?? 0}
        onPageChange={setPage}
        toolbar={
          <div className="flex gap-1.5">
            {ROLE_FILTERS.map((filter) => (
              <button
                key={filter.value}
                onClick={() => {
                  setRole(filter.value);
                  setPage(1);
                }}
                className={cn(
                  'rounded-lg px-3 py-1.5 text-sm font-medium transition',
                  role === filter.value
                    ? 'bg-brand-600 text-white'
                    : 'border border-slate-200 text-slate-600 hover:bg-slate-50',
                )}
              >
                {filter.label}
              </button>
            ))}
          </div>
        }
      />
    </div>
  );
}
