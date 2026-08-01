import { cn, statusClasses } from '@/lib/utils';

export function Badge({
  status,
  label,
  className,
}: {
  status: string;
  label?: string;
  className?: string;
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-md px-2 py-1 text-xs font-medium ring-1 ring-inset',
        statusClasses(status),
        className,
      )}
    >
      {label ?? status}
    </span>
  );
}
