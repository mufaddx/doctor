'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { formatDistanceToNow } from 'date-fns';
import { toast } from 'sonner';

import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Column, DataTable } from '@/components/ui/data-table';
import { api, PaginatedResponse } from '@/lib/api-client';
import type { SupportTicket, TicketStatus } from '@/lib/types';
import { cn } from '@/lib/utils';

const STATUS_FILTERS: { label: string; value: TicketStatus | 'ALL' }[] = [
  { label: 'All', value: 'ALL' },
  { label: 'Open', value: 'OPEN' },
  { label: 'In Progress', value: 'IN_PROGRESS' },
  { label: 'Resolved', value: 'RESOLVED' },
];

const NEXT_STATUS: Record<string, TicketStatus | null> = {
  OPEN: 'IN_PROGRESS',
  IN_PROGRESS: 'RESOLVED',
  RESOLVED: 'CLOSED',
  CLOSED: null,
};

export default function TicketsPage() {
  const queryClient = useQueryClient();

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<TicketStatus | 'ALL'>('ALL');
  const [expanded, setExpanded] = useState<string | null>(null);

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['tickets', page, search, status],
    queryFn: () =>
      api.get<PaginatedResponse<SupportTicket>>('/admin/tickets', {
        page,
        limit: 20,
        ...(search ? { search } : {}),
        ...(status !== 'ALL' ? { status } : {}),
      }),
  });

  const updateStatus = useMutation({
    mutationFn: ({ id, next }: { id: string; next: TicketStatus }) =>
      api.patch(`/admin/tickets/${id}`, { status: next }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tickets'] });
      queryClient.invalidateQueries({ queryKey: ['pending-counts'] });
      toast.success('Ticket updated');
    },
    onError: (mutationError: Error) => toast.error(mutationError.message),
  });

  const columns: Column<SupportTicket>[] = [
    {
      key: 'user',
      header: 'Raised By',
      render: (ticket) => (
        <div className="flex items-center gap-3">
          <Avatar
            src={ticket.user.avatarUrl}
            name={ticket.user.fullName}
            size={32}
          />
          <div className="min-w-0">
            <p className="truncate font-medium text-slate-900">
              {ticket.user.fullName}
            </p>
            <p className="text-xs text-slate-500">
              {ticket.user.role.toLowerCase()}
            </p>
          </div>
        </div>
      ),
    },
    {
      key: 'subject',
      header: 'Subject',
      render: (ticket) => (
        <div className="max-w-md">
          <p className="font-medium text-slate-900">{ticket.subject}</p>
          <p
            className={cn(
              'text-xs text-slate-500',
              // Long messages are truncated until the row is expanded
              expanded === ticket.id ? '' : 'line-clamp-1',
            )}
          >
            {ticket.message}
          </p>
          {ticket.message.length > 80 && (
            <button
              onClick={(event) => {
                event.stopPropagation();
                setExpanded(expanded === ticket.id ? null : ticket.id);
              }}
              className="mt-0.5 text-xs font-medium text-brand-600 hover:underline"
            >
              {expanded === ticket.id ? 'Show less' : 'Show more'}
            </button>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (ticket) => <Badge status={ticket.status} />,
    },
    {
      key: 'createdAt',
      header: 'Age',
      render: (ticket) => (
        <span className="whitespace-nowrap text-slate-600">
          {formatDistanceToNow(new Date(ticket.createdAt), { addSuffix: true })}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      align: 'right',
      render: (ticket) => {
        const next = NEXT_STATUS[ticket.status];
        if (!next) return <span className="text-xs text-slate-400">Closed</span>;

        return (
          <button
            disabled={updateStatus.isPending}
            onClick={() => updateStatus.mutate({ id: ticket.id, next })}
            className="whitespace-nowrap rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-700 transition hover:bg-slate-50 disabled:opacity-40"
          >
            Mark {next.replace('_', ' ').toLowerCase()}
          </button>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Support Tickets</h1>
        <p className="mt-1 text-sm text-slate-500">
          Issues raised by patients and therapists
        </p>
      </div>

      <DataTable
        columns={columns}
        rows={data?.items}
        rowKey={(ticket) => ticket.id}
        isLoading={isLoading}
        error={error as Error | null}
        onRetry={refetch}
        emptyTitle="No tickets here"
        emptyMessage="Nothing needs attention right now."
        searchValue={search}
        onSearchChange={(value) => {
          setSearch(value);
          setPage(1);
        }}
        searchPlaceholder="Search by subject"
        page={page}
        totalPages={data?.meta.totalPages ?? 1}
        total={data?.meta.total ?? 0}
        onPageChange={setPage}
        toolbar={
          <div className="flex gap-1.5">
            {STATUS_FILTERS.map((filter) => (
              <button
                key={filter.value}
                onClick={() => {
                  setStatus(filter.value);
                  setPage(1);
                }}
                className={cn(
                  'rounded-lg px-3 py-1.5 text-sm font-medium transition',
                  status === filter.value
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
