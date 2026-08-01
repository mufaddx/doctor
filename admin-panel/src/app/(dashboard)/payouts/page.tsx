'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import { AlertTriangle, Banknote } from 'lucide-react';
import { toast } from 'sonner';

import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Card, CardBody, CardHeader } from '@/components/ui/card';
import { Column, DataTable } from '@/components/ui/data-table';
import { EmptyState, TableSkeleton } from '@/components/ui/states';
import { api, PaginatedResponse } from '@/lib/api-client';
import type { PendingPayout } from '@/lib/types';
import { formatCurrency } from '@/lib/utils';

interface PayoutRecord {
  id: string;
  amount: string;
  status: string;
  processedAt: string | null;
  createdAt: string;
  therapist: { id: string; user: { fullName: string } };
}

export default function PayoutsPage() {
  const queryClient = useQueryClient();

  const [confirming, setConfirming] = useState<PendingPayout | null>(null);
  const [historyPage, setHistoryPage] = useState(1);

  const pending = useQuery({
    queryKey: ['pending-payouts'],
    queryFn: () => api.get<PendingPayout[]>('/admin/payouts/pending'),
  });

  const history = useQuery({
    queryKey: ['payout-history', historyPage],
    queryFn: () =>
      api.get<PaginatedResponse<PayoutRecord>>('/admin/payouts', {
        page: historyPage,
        limit: 20,
      }),
  });

  const createPayout = useMutation({
    mutationFn: ({
      therapistId,
      amount,
    }: {
      therapistId: string;
      amount: number;
    }) => api.post('/admin/payouts', { therapistId, amount }),
    onSuccess: () => {
      // Both the owed list and the history change after a payout
      queryClient.invalidateQueries({ queryKey: ['pending-payouts'] });
      queryClient.invalidateQueries({ queryKey: ['payout-history'] });
      queryClient.invalidateQueries({ queryKey: ['pending-counts'] });

      toast.success('Payout recorded and the therapist has been notified');
      setConfirming(null);
    },
    onError: (error: Error) => toast.error(error.message),
  });

  const totalOwed =
    pending.data?.reduce((sum, row) => sum + row.pendingAmount, 0) ?? 0;

  const historyColumns: Column<PayoutRecord>[] = [
    {
      key: 'therapist',
      header: 'Therapist',
      render: (row) => (
        <span className="font-medium text-slate-900">
          {row.therapist.user.fullName}
        </span>
      ),
    },
    {
      key: 'amount',
      header: 'Amount',
      render: (row) => (
        <span className="font-medium text-slate-900">
          {formatCurrency(row.amount)}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <Badge status={row.status} />,
    },
    {
      key: 'processedAt',
      header: 'Processed',
      render: (row) => (
        <span className="text-slate-600">
          {row.processedAt
            ? format(new Date(row.processedAt), 'd MMM yyyy, h:mm a')
            : '—'}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Payouts</h1>
          <p className="mt-1 text-sm text-slate-500">
            Settle earnings owed to therapists
          </p>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white px-5 py-3">
          <p className="text-xs font-medium text-slate-500">Total Owed</p>
          <p className="text-xl font-bold text-brand-600">
            {formatCurrency(totalOwed)}
          </p>
        </div>
      </div>

      <Card>
        <CardHeader title="Pending Payouts" />

        {pending.isLoading ? (
          <TableSkeleton />
        ) : !pending.data?.length ? (
          <EmptyState
            title="Everyone is settled up"
            message="No therapist currently has an outstanding balance."
          />
        ) : (
          <div className="divide-y divide-slate-50">
            {pending.data.map((row) => (
              <div
                key={row.therapistId}
                className="flex flex-wrap items-center gap-4 px-5 py-4"
              >
                <Avatar src={row.avatarUrl} name={row.fullName} size={40} />

                <div className="min-w-0 flex-1">
                  <p className="font-medium text-slate-900">{row.fullName}</p>
                  <p className="text-xs text-slate-500">
                    Earned {formatCurrency(row.totalEarned)} · Paid{' '}
                    {formatCurrency(row.alreadyPaid)}
                  </p>
                </div>

                <div className="text-right">
                  <p className="text-xs text-slate-500">Pending</p>
                  <p className="font-semibold text-slate-900">
                    {formatCurrency(row.pendingAmount)}
                  </p>
                </div>

                {/* Unverified bank details block the payout entirely */}
                {row.bankVerified ? (
                  <button
                    onClick={() => setConfirming(row)}
                    className="inline-flex items-center gap-1.5 rounded-lg bg-brand-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-brand-700"
                  >
                    <Banknote className="h-4 w-4" />
                    Pay Out
                  </button>
                ) : (
                  <span className="inline-flex items-center gap-1.5 rounded-lg bg-amber-50 px-3 py-2 text-xs font-medium text-amber-700 ring-1 ring-inset ring-amber-200">
                    <AlertTriangle className="h-3.5 w-3.5" />
                    Bank not verified
                  </span>
                )}
              </div>
            ))}
          </div>
        )}
      </Card>

      <div>
        <h2 className="mb-3 text-lg font-semibold text-slate-900">
          Payout History
        </h2>

        <DataTable
          columns={historyColumns}
          rows={history.data?.items}
          rowKey={(row) => row.id}
          isLoading={history.isLoading}
          error={history.error as Error | null}
          onRetry={history.refetch}
          emptyTitle="No payouts recorded yet"
          page={historyPage}
          totalPages={history.data?.meta.totalPages ?? 1}
          total={history.data?.meta.total ?? 0}
          onPageChange={setHistoryPage}
        />
      </div>

      {confirming && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm animate-slide-in rounded-xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-semibold text-slate-900">
              Confirm payout
            </h3>
            <p className="mt-2 text-sm text-slate-600">
              Transfer{' '}
              <span className="font-semibold text-slate-900">
                {formatCurrency(confirming.pendingAmount)}
              </span>{' '}
              to {confirming.fullName} at {confirming.bankName}?
            </p>
            <p className="mt-3 rounded-lg bg-amber-50 p-3 text-xs text-amber-800">
              This records the payout in the ledger. Make the bank transfer
              separately before confirming.
            </p>

            <div className="mt-5 flex justify-end gap-2">
              <button
                onClick={() => setConfirming(null)}
                className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                disabled={createPayout.isPending}
                onClick={() =>
                  createPayout.mutate({
                    therapistId: confirming.therapistId,
                    amount: confirming.pendingAmount,
                  })
                }
                className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
              >
                Confirm Payout
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
