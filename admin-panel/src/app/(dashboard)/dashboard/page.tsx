'use client';

import { useQuery } from '@tanstack/react-query';
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  ArrowDownRight,
  ArrowUpRight,
  CalendarDays,
  IndianRupee,
  Stethoscope,
  UserRound,
  Users,
} from 'lucide-react';
import Link from 'next/link';
import { format } from 'date-fns';

import { Card, CardBody, CardHeader } from '@/components/ui/card';
import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { ChartSkeleton, EmptyState, ErrorState, TableSkeleton } from '@/components/ui/states';
import { api } from '@/lib/api-client';
import type {
  AppointmentOverviewPoint,
  AppointmentTypeShare,
  DashboardStats,
  LatestAppointment,
  RecentReview,
  RevenueOverview,
  SecondaryStats,
  TopTherapist,
} from '@/lib/types';
import {
  cn,
  formatCompact,
  formatCurrency,
  formatNumber,
  monthLabel,
  readableStatus,
  readableType,
} from '@/lib/utils';

const TYPE_COLORS: Record<string, string> = {
  VIDEO_CONSULTATION: '#0f766e',
  HOME_VISIT: '#8b5cf6',
  CLINIC_VISIT: '#3b82f6',
};

export default function DashboardPage() {
  const stats = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.get<DashboardStats>('/admin/dashboard/stats'),
  });

  const secondary = useQuery({
    queryKey: ['dashboard-secondary'],
    queryFn: () => api.get<SecondaryStats>('/admin/dashboard/secondary-stats'),
  });

  const appointments = useQuery({
    queryKey: ['appointments-overview'],
    queryFn: () =>
      api.get<AppointmentOverviewPoint[]>(
        '/admin/dashboard/appointments-overview',
        { months: 6 },
      ),
  });

  const revenue = useQuery({
    queryKey: ['revenue-overview'],
    queryFn: () =>
      api.get<RevenueOverview>('/admin/dashboard/revenue-overview', {
        months: 6,
      }),
  });

  const byType = useQuery({
    queryKey: ['appointments-by-type'],
    queryFn: () =>
      api.get<AppointmentTypeShare[]>('/admin/dashboard/appointments-by-type'),
  });

  const topTherapists = useQuery({
    queryKey: ['top-therapists'],
    queryFn: () => api.get<TopTherapist[]>('/admin/dashboard/top-therapists'),
  });

  const latest = useQuery({
    queryKey: ['latest-appointments'],
    queryFn: () =>
      api.get<LatestAppointment[]>('/admin/dashboard/latest-appointments'),
  });

  const reviews = useQuery({
    queryKey: ['recent-reviews'],
    queryFn: () => api.get<RecentReview[]>('/admin/dashboard/recent-reviews'),
  });

  const kpis = [
    {
      label: 'Total Users',
      metric: stats.data?.totalUsers,
      icon: Users,
      tint: 'bg-teal-50 text-teal-600',
      format: formatNumber,
    },
    {
      label: 'Therapists',
      metric: stats.data?.therapists,
      icon: Stethoscope,
      tint: 'bg-blue-50 text-blue-600',
      format: formatNumber,
    },
    {
      label: 'Patients',
      metric: stats.data?.patients,
      icon: UserRound,
      tint: 'bg-violet-50 text-violet-600',
      format: formatNumber,
    },
    {
      label: 'Appointments',
      metric: stats.data?.totalAppointments,
      icon: CalendarDays,
      tint: 'bg-amber-50 text-amber-600',
      format: formatNumber,
    },
    {
      label: 'Total Revenue',
      metric: stats.data?.totalRevenue,
      icon: IndianRupee,
      tint: 'bg-rose-50 text-rose-600',
      format: formatCurrency,
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p className="mt-1 text-sm text-slate-500">
          Platform overview for the last 6 months
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
        {kpis.map((kpi) => (
          <Card key={kpi.label}>
            <CardBody>
              {stats.isLoading ? (
                <div className="h-16 animate-pulse rounded bg-slate-100" />
              ) : (
                <>
                  <div className="flex items-start justify-between">
                    <div className={cn('rounded-lg p-2.5', kpi.tint)}>
                      <kpi.icon className="h-5 w-5" />
                    </div>
                  </div>
                  <p className="mt-3 text-xs font-medium text-slate-500">
                    {kpi.label}
                  </p>
                  <p className="mt-0.5 text-2xl font-bold text-slate-900">
                    {kpi.metric ? kpi.format(kpi.metric.value) : '—'}
                  </p>
                  {kpi.metric && <ChangeIndicator value={kpi.metric.changePercent} />}
                </>
              )}
            </CardBody>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader title="Appointments Overview" />
          <CardBody>
            {appointments.isLoading ? (
              <ChartSkeleton />
            ) : appointments.isError ? (
              <ErrorState
                message="Could not load appointment trends"
                onRetry={() => appointments.refetch()}
              />
            ) : (
              <ResponsiveContainer width="100%" height={280}>
                <AreaChart
                  data={appointments.data?.map((point) => ({
                    ...point,
                    label: monthLabel(point.month),
                  }))}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                  <XAxis
                    dataKey="label"
                    tick={{ fontSize: 12, fill: '#64748b' }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <YAxis
                    tick={{ fontSize: 12, fill: '#64748b' }}
                    axisLine={false}
                    tickLine={false}
                  />
                  <Tooltip
                    contentStyle={{
                      borderRadius: 8,
                      border: '1px solid #e2e8f0',
                      fontSize: 12,
                    }}
                  />
                  <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} />
                  <Area
                    type="monotone"
                    dataKey="completed"
                    name="Completed"
                    stroke="#0f766e"
                    fill="#0f766e"
                    fillOpacity={0.12}
                    strokeWidth={2}
                  />
                  <Area
                    type="monotone"
                    dataKey="upcoming"
                    name="Upcoming"
                    stroke="#3b82f6"
                    fill="#3b82f6"
                    fillOpacity={0.1}
                    strokeWidth={2}
                  />
                  <Area
                    type="monotone"
                    dataKey="cancelled"
                    name="Cancelled"
                    stroke="#ef4444"
                    fill="#ef4444"
                    fillOpacity={0.08}
                    strokeWidth={2}
                  />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Revenue Overview" />
          <CardBody>
            {revenue.isLoading ? (
              <ChartSkeleton />
            ) : (
              <>
                <p className="text-2xl font-bold text-slate-900">
                  {formatCurrency(revenue.data?.total ?? 0)}
                </p>
                {stats.data && (
                  <ChangeIndicator
                    value={stats.data.totalRevenue.changePercent}
                  />
                )}

                <ResponsiveContainer width="100%" height={210} className="mt-4">
                  <BarChart
                    data={revenue.data?.series.map((point) => ({
                      ...point,
                      label: monthLabel(point.month),
                    }))}
                  >
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="#f1f5f9"
                      vertical={false}
                    />
                    <XAxis
                      dataKey="label"
                      tick={{ fontSize: 11, fill: '#64748b' }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <YAxis
                      tickFormatter={formatCompact}
                      tick={{ fontSize: 11, fill: '#64748b' }}
                      axisLine={false}
                      tickLine={false}
                    />
                    <Tooltip
                      formatter={(value: number) => formatCurrency(value)}
                      contentStyle={{
                        borderRadius: 8,
                        border: '1px solid #e2e8f0',
                        fontSize: 12,
                      }}
                    />
                    <Bar dataKey="revenue" fill="#0f766e" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </>
            )}
          </CardBody>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader
            title="Latest Appointments"
            action={
              <Link
                href="/appointments"
                className="text-sm font-medium text-brand-600 hover:underline"
              >
                View All
              </Link>
            }
          />
          {latest.isLoading ? (
            <TableSkeleton />
          ) : !latest.data?.length ? (
            <EmptyState title="No appointments yet" />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="border-b border-slate-100 text-left text-xs font-medium text-slate-500">
                  <tr>
                    <th className="px-5 py-3">Patient</th>
                    <th className="px-5 py-3">Therapist</th>
                    <th className="px-5 py-3">Type</th>
                    <th className="px-5 py-3">Date &amp; Time</th>
                    <th className="px-5 py-3">Status</th>
                    <th className="px-5 py-3 text-right">Amount</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50">
                  {latest.data.map((appointment) => (
                    <tr key={appointment.id} className="hover:bg-slate-50">
                      <td className="px-5 py-3">
                        <div className="flex items-center gap-2.5">
                          <Avatar
                            src={appointment.patient.user.avatarUrl}
                            name={appointment.patient.user.fullName}
                            size={30}
                          />
                          <span className="font-medium text-slate-900">
                            {appointment.patient.user.fullName}
                          </span>
                        </div>
                      </td>
                      <td className="px-5 py-3 text-slate-600">
                        {appointment.therapist.user.fullName}
                      </td>
                      <td className="px-5 py-3">
                        <span className="rounded-md bg-slate-100 px-2 py-1 text-xs text-slate-700">
                          {readableType(appointment.type)}
                        </span>
                      </td>
                      <td className="px-5 py-3 text-slate-600">
                        {format(new Date(appointment.scheduledDate), 'd MMM yyyy')},{' '}
                        {appointment.startTime}
                      </td>
                      <td className="px-5 py-3">
                        <Badge
                          status={appointment.status}
                          label={readableStatus(appointment.status)}
                        />
                      </td>
                      <td className="px-5 py-3 text-right font-medium text-slate-900">
                        {formatCurrency(appointment.totalAmount)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <div className="space-y-6">
          <Card>
            <CardHeader title="Appointments by Type" />
            <CardBody>
              {byType.isLoading ? (
                <ChartSkeleton height={180} />
              ) : (
                <>
                  <ResponsiveContainer width="100%" height={170}>
                    <PieChart>
                      <Pie
                        data={byType.data}
                        dataKey="count"
                        nameKey="type"
                        innerRadius={48}
                        outerRadius={70}
                        paddingAngle={2}
                      >
                        {byType.data?.map((entry) => (
                          <Cell
                            key={entry.type}
                            fill={TYPE_COLORS[entry.type] ?? '#f59e0b'}
                          />
                        ))}
                      </Pie>
                      <Tooltip
                        formatter={(value: number, name: string) => [
                          value,
                          readableType(name),
                        ]}
                      />
                    </PieChart>
                  </ResponsiveContainer>

                  <ul className="mt-3 space-y-2">
                    {byType.data?.map((entry) => (
                      <li
                        key={entry.type}
                        className="flex items-center justify-between text-sm"
                      >
                        <span className="flex items-center gap-2 text-slate-600">
                          <span
                            className="h-2.5 w-2.5 rounded-full"
                            style={{
                              backgroundColor:
                                TYPE_COLORS[entry.type] ?? '#f59e0b',
                            }}
                          />
                          {readableType(entry.type)}
                        </span>
                        <span className="font-medium text-slate-900">
                          {entry.percentage}%
                        </span>
                      </li>
                    ))}
                  </ul>
                </>
              )}
            </CardBody>
          </Card>

          <Card>
            <CardHeader
              title="Top Therapists"
              action={
                <Link
                  href="/therapists"
                  className="text-sm font-medium text-brand-600 hover:underline"
                >
                  View All
                </Link>
              }
            />
            <CardBody className="space-y-3">
              {topTherapists.isLoading ? (
                <TableSkeleton rows={4} />
              ) : (
                topTherapists.data?.map((therapist) => (
                  <div key={therapist.id} className="flex items-center gap-3">
                    <Avatar
                      src={therapist.avatarUrl}
                      name={therapist.fullName}
                      size={36}
                    />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-slate-900">
                        {therapist.fullName}
                      </p>
                      <p className="text-xs text-slate-500">
                        {therapist.appointmentCount} appointments
                      </p>
                    </div>
                    <span className="flex items-center gap-1 text-sm font-medium text-amber-500">
                      ★ {therapist.rating.toFixed(1)}
                    </span>
                  </div>
                ))
              )}
            </CardBody>
          </Card>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <SecondaryCard
          label="Pending Payments"
          value={secondary.data?.pendingPayments.count}
          subtitle={
            secondary.data
              ? formatCurrency(secondary.data.pendingPayments.amount)
              : undefined
          }
          tint="bg-amber-50 text-amber-600"
        />
        <SecondaryCard
          label="Unpaid Appointments"
          value={secondary.data?.unpaidAppointments.count}
          subtitle={
            secondary.data
              ? formatCurrency(secondary.data.unpaidAppointments.amount)
              : undefined
          }
          tint="bg-rose-50 text-rose-600"
        />
        <SecondaryCard
          label="Therapists on Leave"
          value={secondary.data?.therapistsOnLeave}
          tint="bg-violet-50 text-violet-600"
        />
        <SecondaryCard
          label="Active Offers"
          value={secondary.data?.activeOffers}
          tint="bg-emerald-50 text-emerald-600"
        />
      </div>

      <Card>
        <CardHeader
          title="Recent Reviews"
          action={
            <Link
              href="/reviews"
              className="text-sm font-medium text-brand-600 hover:underline"
            >
              View All
            </Link>
          }
        />
        <CardBody className="space-y-4">
          {reviews.isLoading ? (
            <TableSkeleton rows={3} />
          ) : !reviews.data?.length ? (
            <EmptyState title="No reviews yet" />
          ) : (
            reviews.data.map((review) => (
              <div key={review.id} className="flex gap-3">
                <Avatar
                  src={review.author.avatarUrl}
                  name={review.author.fullName}
                  size={36}
                />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className="truncate text-sm font-medium text-slate-900">
                      {review.author.fullName}
                    </p>
                    <span className="shrink-0 text-xs text-slate-400">
                      {format(new Date(review.createdAt), 'd MMM')}
                    </span>
                  </div>
                  <p className="text-xs text-amber-500">
                    {'★'.repeat(review.rating)}
                    <span className="text-slate-300">
                      {'★'.repeat(5 - review.rating)}
                    </span>
                  </p>
                  {review.comment && (
                    <p className="mt-1 text-sm text-slate-600">{review.comment}</p>
                  )}
                </div>
              </div>
            ))
          )}
        </CardBody>
      </Card>
    </div>
  );
}

/** Green up-arrow for growth, red down-arrow for decline. */
function ChangeIndicator({ value }: { value: number }) {
  const positive = value >= 0;
  const Icon = positive ? ArrowUpRight : ArrowDownRight;

  return (
    <p
      className={cn(
        'mt-1 flex items-center gap-1 text-xs font-medium',
        positive ? 'text-emerald-600' : 'text-rose-600',
      )}
    >
      <Icon className="h-3.5 w-3.5" />
      {Math.abs(value)}% from last month
    </p>
  );
}

function SecondaryCard({
  label,
  value,
  subtitle,
  tint,
}: {
  label: string;
  value?: number;
  subtitle?: string;
  tint: string;
}) {
  return (
    <Card>
      <CardBody className="flex items-center gap-4">
        <div className={cn('rounded-lg p-3', tint)}>
          <CalendarDays className="h-5 w-5" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-500">{label}</p>
          <p className="text-xl font-bold text-slate-900">
            {value !== undefined ? formatNumber(value) : '—'}
          </p>
          {subtitle && <p className="text-xs text-slate-500">{subtitle}</p>}
        </div>
      </CardBody>
    </Card>
  );
}
