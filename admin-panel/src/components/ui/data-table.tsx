'use client';

import { useState } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  Search,
} from 'lucide-react';

import { EmptyState, ErrorState, TableSkeleton } from '@/components/ui/states';
import { cn } from '@/lib/utils';

export interface Column<T> {
  key: string;
  header: string;
  /** Renders the cell; receives the whole row so it can combine fields. */
  render: (row: T) => React.ReactNode;
  /** Enables the sort toggle on this column's header. */
  sortable?: boolean;
  align?: 'left' | 'right' | 'center';
  className?: string;
}

export interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[] | undefined;
  rowKey: (row: T) => string;
  isLoading?: boolean;
  error?: Error | null;
  onRetry?: () => void;

  emptyTitle?: string;
  emptyMessage?: string;

  searchValue?: string;
  onSearchChange?: (value: string) => void;
  searchPlaceholder?: string;

  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  onSortChange?: (sortBy: string, sortOrder: 'asc' | 'desc') => void;

  page?: number;
  totalPages?: number;
  total?: number;
  onPageChange?: (page: number) => void;

  /** Extra controls rendered next to the search box, e.g. status filters. */
  toolbar?: React.ReactNode;
  onRowClick?: (row: T) => void;
}

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  isLoading,
  error,
  onRetry,
  emptyTitle = 'Nothing here yet',
  emptyMessage,
  searchValue,
  onSearchChange,
  searchPlaceholder = 'Search...',
  sortBy,
  sortOrder = 'desc',
  onSortChange,
  page = 1,
  totalPages = 1,
  total = 0,
  onPageChange,
  toolbar,
  onRowClick,
}: DataTableProps<T>) {
  const [localSearch, setLocalSearch] = useState(searchValue ?? '');

  /**
   * Search is debounced here rather than in every page, so a fast typist
   * produces one request instead of one per keystroke.
   */
  const handleSearch = (value: string) => {
    setLocalSearch(value);

    if (!onSearchChange) return;

    window.clearTimeout((handleSearch as { timer?: number }).timer);
    (handleSearch as { timer?: number }).timer = window.setTimeout(
      () => onSearchChange(value),
      400,
    );
  };

  const toggleSort = (key: string) => {
    if (!onSortChange) return;

    // Clicking the active column flips direction; a new column starts desc
    const nextOrder =
      sortBy === key && sortOrder === 'desc' ? 'asc' : 'desc';
    onSortChange(key, nextOrder);
  };

  return (
    <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
      {(onSearchChange || toolbar) && (
        <div className="flex flex-wrap items-center gap-3 border-b border-slate-100 p-4">
          {onSearchChange && (
            <div className="relative min-w-[220px] flex-1">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                value={localSearch}
                onChange={(event) => handleSearch(event.target.value)}
                placeholder={searchPlaceholder}
                className="w-full rounded-lg border border-slate-200 py-2 pl-9 pr-3 text-sm outline-none transition focus:border-brand-500 focus:ring-2 focus:ring-brand-100"
              />
            </div>
          )}
          {toolbar}
        </div>
      )}

      {isLoading ? (
        <TableSkeleton />
      ) : error ? (
        <ErrorState message={error.message} onRetry={onRetry} />
      ) : !rows?.length ? (
        <EmptyState title={emptyTitle} message={emptyMessage} />
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b border-slate-100 text-left text-xs font-medium text-slate-500">
              <tr>
                {columns.map((column) => (
                  <th
                    key={column.key}
                    className={cn(
                      'whitespace-nowrap px-5 py-3',
                      column.align === 'right' && 'text-right',
                      column.align === 'center' && 'text-center',
                      column.sortable && 'cursor-pointer select-none hover:text-slate-700',
                    )}
                    onClick={
                      column.sortable ? () => toggleSort(column.key) : undefined
                    }
                  >
                    <span className="inline-flex items-center gap-1">
                      {column.header}
                      {column.sortable && (
                        <ChevronsUpDown
                          className={cn(
                            'h-3 w-3',
                            sortBy === column.key
                              ? 'text-brand-600'
                              : 'text-slate-300',
                          )}
                        />
                      )}
                    </span>
                  </th>
                ))}
              </tr>
            </thead>

            <tbody className="divide-y divide-slate-50">
              {rows.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  className={cn(
                    'hover:bg-slate-50',
                    onRowClick && 'cursor-pointer',
                  )}
                >
                  {columns.map((column) => (
                    <td
                      key={column.key}
                      className={cn(
                        'px-5 py-3',
                        column.align === 'right' && 'text-right',
                        column.align === 'center' && 'text-center',
                        column.className,
                      )}
                    >
                      {column.render(row)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {onPageChange && totalPages > 1 && (
        <div className="flex items-center justify-between border-t border-slate-100 px-5 py-3">
          <p className="text-sm text-slate-500">
            Page {page} of {totalPages} · {total} records
          </p>

          <div className="flex items-center gap-1">
            <button
              onClick={() => onPageChange(page - 1)}
              disabled={page <= 1}
              className="rounded-lg border border-slate-200 p-1.5 text-slate-600 transition hover:bg-slate-50 disabled:opacity-40"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={() => onPageChange(page + 1)}
              disabled={page >= totalPages}
              className="rounded-lg border border-slate-200 p-1.5 text-slate-600 transition hover:bg-slate-50 disabled:opacity-40"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
