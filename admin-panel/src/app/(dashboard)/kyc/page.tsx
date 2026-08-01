'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import { Check, ExternalLink, FileText, X } from 'lucide-react';
import { toast } from 'sonner';

import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Card, CardBody } from '@/components/ui/card';
import { EmptyState, ErrorState, TableSkeleton } from '@/components/ui/states';
import { api, PaginatedResponse } from '@/lib/api-client';
import type { KycCandidate, KycStatus } from '@/lib/types';
import { cn } from '@/lib/utils';

const STATUS_TABS: { label: string; value: KycStatus }[] = [
  { label: 'Pending', value: 'PENDING' },
  { label: 'Approved', value: 'APPROVED' },
  { label: 'Rejected', value: 'REJECTED' },
];

export default function KycPage() {
  const queryClient = useQueryClient();

  const [status, setStatus] = useState<KycStatus>('PENDING');
  const [rejecting, setRejecting] = useState<KycCandidate | null>(null);
  const [reason, setReason] = useState('');

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['kyc-queue', status],
    queryFn: () =>
      api.get<PaginatedResponse<KycCandidate>>('/admin/kyc', {
        status,
        limit: 50,
      }),
  });

  const decide = useMutation({
    mutationFn: ({
      therapistId,
      approve,
      rejectReason,
    }: {
      therapistId: string;
      approve: boolean;
      rejectReason?: string;
    }) =>
      api.patch(`/admin/kyc/${therapistId}`, {
        approve,
        ...(rejectReason ? { reason: rejectReason } : {}),
      }),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['kyc-queue'] });
      // The sidebar badge counts this queue, so refresh it too
      queryClient.invalidateQueries({ queryKey: ['pending-counts'] });

      toast.success(
        variables.approve
          ? 'Therapist verified and now visible to patients'
          : 'Verification rejected',
      );

      setRejecting(null);
      setReason('');
    },
    onError: (mutationError: Error) => toast.error(mutationError.message),
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">KYC Verification</h1>
        <p className="mt-1 text-sm text-slate-500">
          Approve therapists before they become discoverable in patient search
        </p>
      </div>

      <div className="flex gap-1.5">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatus(tab.value)}
            className={cn(
              'rounded-lg px-4 py-2 text-sm font-medium transition',
              status === tab.value
                ? 'bg-brand-600 text-white'
                : 'border border-slate-200 bg-white text-slate-600 hover:bg-slate-50',
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {isLoading ? (
        <Card>
          <TableSkeleton />
        </Card>
      ) : error ? (
        <Card>
          <ErrorState message={(error as Error).message} onRetry={refetch} />
        </Card>
      ) : !data?.items.length ? (
        <Card>
          <EmptyState
            title="Nothing in this queue"
            message={
              status === 'PENDING'
                ? 'All submitted verifications have been reviewed.'
                : undefined
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {data.items.map((candidate) => (
            <Card key={candidate.id}>
              <CardBody className="space-y-4">
                <div className="flex items-start gap-3">
                  <Avatar
                    src={candidate.user.avatarUrl}
                    name={candidate.user.fullName}
                    size={48}
                  />
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold text-slate-900">
                      {candidate.user.fullName}
                    </p>
                    <p className="text-sm text-slate-500">
                      +91 {candidate.user.phone}
                    </p>
                    {candidate.user.email && (
                      <p className="truncate text-sm text-slate-500">
                        {candidate.user.email}
                      </p>
                    )}
                  </div>
                  <Badge status={candidate.kycStatus} />
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-xs text-slate-500">Experience</p>
                    <p className="font-medium text-slate-900">
                      {candidate.experienceYears} years
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500">Submitted</p>
                    <p className="font-medium text-slate-900">
                      {format(new Date(candidate.createdAt), 'd MMM yyyy')}
                    </p>
                  </div>
                </div>

                {candidate.specialization.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {candidate.specialization.map((item) => (
                      <span
                        key={item}
                        className="rounded-md bg-slate-100 px-2 py-1 text-xs text-slate-700"
                      >
                        {item}
                      </span>
                    ))}
                  </div>
                )}

                <div>
                  <p className="mb-2 text-xs font-medium text-slate-500">
                    Certificates ({candidate.certificates.length})
                  </p>

                  {candidate.certificates.length === 0 ? (
                    <p className="text-sm text-rose-600">
                      No documents uploaded yet
                    </p>
                  ) : (
                    <ul className="space-y-1.5">
                      {candidate.certificates.map((certificate) => (
                        <li key={certificate.id}>
                          <a
                            href={certificate.fileUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700 transition hover:bg-slate-50"
                          >
                            <FileText className="h-4 w-4 shrink-0 text-slate-400" />
                            <span className="min-w-0 flex-1 truncate">
                              {certificate.title}
                            </span>
                            <ExternalLink className="h-3.5 w-3.5 shrink-0 text-slate-400" />
                          </a>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>

                <div className="rounded-lg bg-slate-50 p-3 text-sm">
                  <p className="text-xs font-medium text-slate-500">
                    Bank Details
                  </p>
                  {candidate.bankDetail ? (
                    <p className="mt-1 text-slate-700">
                      {candidate.bankDetail.bankName} ·{' '}
                      {candidate.bankDetail.ifscCode}
                    </p>
                  ) : (
                    <p className="mt-1 text-amber-600">
                      Not submitted — payouts will be blocked
                    </p>
                  )}
                </div>

                {status === 'PENDING' && (
                  <div className="flex gap-2">
                    <button
                      disabled={
                        decide.isPending || candidate.certificates.length === 0
                      }
                      onClick={() =>
                        decide.mutate({
                          therapistId: candidate.id,
                          approve: true,
                        })
                      }
                      title={
                        candidate.certificates.length === 0
                          ? 'Cannot approve without any documents'
                          : undefined
                      }
                      className="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-brand-600 py-2 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
                    >
                      <Check className="h-4 w-4" />
                      Approve
                    </button>
                    <button
                      disabled={decide.isPending}
                      onClick={() => setRejecting(candidate)}
                      className="flex flex-1 items-center justify-center gap-1.5 rounded-lg border border-rose-200 py-2 text-sm font-medium text-rose-600 transition hover:bg-rose-50 disabled:opacity-40"
                    >
                      <X className="h-4 w-4" />
                      Reject
                    </button>
                  </div>
                )}
              </CardBody>
            </Card>
          ))}
        </div>
      )}

      {rejecting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md animate-slide-in rounded-xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-semibold text-slate-900">
              Reject verification
            </h3>
            <p className="mt-1 text-sm text-slate-500">
              {rejecting.user.fullName} will be notified with this reason.
            </p>

            <textarea
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              rows={3}
              maxLength={300}
              placeholder="e.g. The uploaded certificate is not legible"
              className="mt-4 w-full rounded-lg border border-slate-200 p-3 text-sm outline-none transition focus:border-brand-500 focus:ring-2 focus:ring-brand-100"
            />

            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => {
                  setRejecting(null);
                  setReason('');
                }}
                className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                disabled={decide.isPending || reason.trim().length < 5}
                onClick={() =>
                  decide.mutate({
                    therapistId: rejecting.id,
                    approve: false,
                    rejectReason: reason.trim(),
                  })
                }
                className="rounded-lg bg-rose-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-rose-700 disabled:opacity-40"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
