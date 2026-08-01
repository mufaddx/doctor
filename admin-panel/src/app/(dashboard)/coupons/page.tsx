'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import { Plus, Power } from 'lucide-react';
import { toast } from 'sonner';

import { Badge } from '@/components/ui/badge';
import { Column, DataTable } from '@/components/ui/data-table';
import { api, PaginatedResponse } from '@/lib/api-client';
import type { Coupon } from '@/lib/types';
import { formatCurrency } from '@/lib/utils';

interface CouponForm {
  code: string;
  type: 'PERCENTAGE' | 'FLAT';
  value: string;
  maxDiscount: string;
  minOrderValue: string;
  usageLimit: string;
  validFrom: string;
  validUntil: string;
}

const EMPTY_FORM: CouponForm = {
  code: '',
  type: 'PERCENTAGE',
  value: '',
  maxDiscount: '',
  minOrderValue: '',
  usageLimit: '',
  validFrom: '',
  validUntil: '',
};

export default function CouponsPage() {
  const queryClient = useQueryClient();

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<CouponForm>(EMPTY_FORM);

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['coupons', page, search],
    queryFn: () =>
      api.get<PaginatedResponse<Coupon>>('/coupons', {
        page,
        limit: 20,
        ...(search ? { search } : {}),
      }),
  });

  const createCoupon = useMutation({
    mutationFn: (payload: Record<string, unknown>) =>
      api.post('/coupons', payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coupons'] });
      toast.success('Coupon created');
      setShowForm(false);
      setForm(EMPTY_FORM);
    },
    onError: (mutationError: Error) => toast.error(mutationError.message),
  });

  const deactivate = useMutation({
    mutationFn: (id: string) => api.delete(`/coupons/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coupons'] });
      toast.success('Coupon deactivated');
    },
    onError: (mutationError: Error) => toast.error(mutationError.message),
  });

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();

    if (!/^[A-Z0-9]{4,20}$/i.test(form.code)) {
      toast.error('Code must be 4-20 alphanumeric characters');
      return;
    }

    const value = Number(form.value);
    if (!value || value <= 0) {
      toast.error('Enter a valid discount value');
      return;
    }
    if (form.type === 'PERCENTAGE' && value > 100) {
      toast.error('A percentage discount cannot exceed 100');
      return;
    }
    if (new Date(form.validUntil) <= new Date(form.validFrom)) {
      toast.error('The end date must be after the start date');
      return;
    }

    createCoupon.mutate({
      code: form.code.toUpperCase(),
      type: form.type,
      value,
      // Empty optional fields are omitted rather than sent as zero
      ...(form.maxDiscount ? { maxDiscount: Number(form.maxDiscount) } : {}),
      ...(form.minOrderValue
        ? { minOrderValue: Number(form.minOrderValue) }
        : {}),
      ...(form.usageLimit ? { usageLimit: Number(form.usageLimit) } : {}),
      validFrom: new Date(form.validFrom).toISOString(),
      validUntil: new Date(form.validUntil).toISOString(),
    });
  };

  const columns: Column<Coupon>[] = [
    {
      key: 'code',
      header: 'Code',
      render: (coupon) => (
        <span className="rounded-md bg-brand-50 px-2 py-1 font-mono text-xs font-bold text-brand-700">
          {coupon.code}
        </span>
      ),
    },
    {
      key: 'discount',
      header: 'Discount',
      render: (coupon) => (
        <span className="text-slate-700">
          {coupon.type === 'PERCENTAGE'
            ? `${coupon.value}%${coupon.maxDiscount ? ` up to ${formatCurrency(coupon.maxDiscount)}` : ''}`
            : formatCurrency(coupon.value)}
        </span>
      ),
    },
    {
      key: 'minOrder',
      header: 'Min Order',
      render: (coupon) => (
        <span className="text-slate-600">
          {coupon.minOrderValue ? formatCurrency(coupon.minOrderValue) : '—'}
        </span>
      ),
    },
    {
      key: 'usage',
      header: 'Usage',
      render: (coupon) => (
        <span className="text-slate-600">
          {coupon.usedCount}
          {coupon.usageLimit ? ` / ${coupon.usageLimit}` : ''}
        </span>
      ),
    },
    {
      key: 'validity',
      header: 'Valid Until',
      render: (coupon) => (
        <span className="whitespace-nowrap text-slate-600">
          {format(new Date(coupon.validUntil), 'd MMM yyyy')}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (coupon) => {
        // A coupon past its end date is effectively expired even if active
        const expired = new Date(coupon.validUntil) < new Date();

        return (
          <Badge
            status={coupon.isActive && !expired ? 'APPROVED' : 'REJECTED'}
            label={expired ? 'Expired' : coupon.isActive ? 'Active' : 'Disabled'}
          />
        );
      },
    },
    {
      key: 'actions',
      header: '',
      align: 'right',
      render: (coupon) =>
        coupon.isActive ? (
          <button
            disabled={deactivate.isPending}
            onClick={() => deactivate.mutate(coupon.id)}
            className="inline-flex items-center gap-1.5 rounded-lg border border-rose-200 px-2.5 py-1.5 text-xs font-medium text-rose-600 transition hover:bg-rose-50 disabled:opacity-40"
          >
            <Power className="h-3.5 w-3.5" />
            Disable
          </button>
        ) : null,
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Coupons</h1>
          <p className="mt-1 text-sm text-slate-500">
            Promotional offers available at checkout
          </p>
        </div>

        <button
          onClick={() => setShowForm(true)}
          className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-brand-700"
        >
          <Plus className="h-4 w-4" />
          New Coupon
        </button>
      </div>

      <DataTable
        columns={columns}
        rows={data?.items}
        rowKey={(coupon) => coupon.id}
        isLoading={isLoading}
        error={error as Error | null}
        onRetry={refetch}
        emptyTitle="No coupons yet"
        emptyMessage="Create one to start running offers."
        searchValue={search}
        onSearchChange={(value) => {
          setSearch(value);
          setPage(1);
        }}
        searchPlaceholder="Search by code"
        page={page}
        totalPages={data?.meta.totalPages ?? 1}
        total={data?.meta.total ?? 0}
        onPageChange={setPage}
      />

      {showForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center overflow-y-auto bg-black/40 p-4">
          <form
            onSubmit={handleSubmit}
            className="w-full max-w-lg animate-slide-in rounded-xl bg-white p-6 shadow-xl"
          >
            <h3 className="text-lg font-semibold text-slate-900">
              Create Coupon
            </h3>

            <div className="mt-5 grid grid-cols-2 gap-4">
              <Field label="Code">
                <input
                  value={form.code}
                  onChange={(event) =>
                    setForm({ ...form, code: event.target.value.toUpperCase() })
                  }
                  placeholder="TOC30"
                  className={inputClass}
                />
              </Field>

              <Field label="Type">
                <select
                  value={form.type}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      type: event.target.value as 'PERCENTAGE' | 'FLAT',
                    })
                  }
                  className={inputClass}
                >
                  <option value="PERCENTAGE">Percentage</option>
                  <option value="FLAT">Flat amount</option>
                </select>
              </Field>

              <Field
                label={form.type === 'PERCENTAGE' ? 'Percentage' : 'Amount (₹)'}
              >
                <input
                  type="number"
                  value={form.value}
                  onChange={(event) =>
                    setForm({ ...form, value: event.target.value })
                  }
                  className={inputClass}
                />
              </Field>

              {/* A cap only makes sense for percentage discounts */}
              {form.type === 'PERCENTAGE' && (
                <Field label="Max Discount (₹)">
                  <input
                    type="number"
                    value={form.maxDiscount}
                    onChange={(event) =>
                      setForm({ ...form, maxDiscount: event.target.value })
                    }
                    placeholder="Optional"
                    className={inputClass}
                  />
                </Field>
              )}

              <Field label="Min Order (₹)">
                <input
                  type="number"
                  value={form.minOrderValue}
                  onChange={(event) =>
                    setForm({ ...form, minOrderValue: event.target.value })
                  }
                  placeholder="Optional"
                  className={inputClass}
                />
              </Field>

              <Field label="Usage Limit">
                <input
                  type="number"
                  value={form.usageLimit}
                  onChange={(event) =>
                    setForm({ ...form, usageLimit: event.target.value })
                  }
                  placeholder="Unlimited"
                  className={inputClass}
                />
              </Field>

              <Field label="Valid From">
                <input
                  type="date"
                  value={form.validFrom}
                  onChange={(event) =>
                    setForm({ ...form, validFrom: event.target.value })
                  }
                  className={inputClass}
                />
              </Field>

              <Field label="Valid Until">
                <input
                  type="date"
                  value={form.validUntil}
                  onChange={(event) =>
                    setForm({ ...form, validUntil: event.target.value })
                  }
                  className={inputClass}
                />
              </Field>
            </div>

            <div className="mt-6 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => {
                  setShowForm(false);
                  setForm(EMPTY_FORM);
                }}
                className="rounded-lg border border-slate-200 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={createCoupon.isPending}
                className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-brand-700 disabled:opacity-40"
              >
                Create Coupon
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}

const inputClass =
  'w-full rounded-lg border border-slate-200 px-3 py-2 text-sm outline-none transition focus:border-brand-500 focus:ring-2 focus:ring-brand-100';

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-medium text-slate-700">
        {label}
      </span>
      {children}
    </label>
  );
}
