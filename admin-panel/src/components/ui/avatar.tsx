'use client';

import Image from 'next/image';
import { useState } from 'react';
import { avatarColor, cn, initials } from '@/lib/utils';

/**
 * Falls back to coloured initials when the image is missing or fails to load,
 * so tables never show empty circles.
 */
export function Avatar({
  src,
  name,
  size = 36,
  className,
}: {
  src?: string | null;
  name: string;
  size?: number;
  className?: string;
}) {
  const [failed, setFailed] = useState(false);

  if (!src || failed) {
    return (
      <div
        className={cn(
          'flex shrink-0 items-center justify-center rounded-full font-semibold text-white',
          avatarColor(name),
          className,
        )}
        style={{ width: size, height: size, fontSize: size * 0.36 }}
      >
        {initials(name)}
      </div>
    );
  }

  return (
    <Image
      src={src}
      alt={name}
      width={size}
      height={size}
      onError={() => setFailed(true)}
      className={cn('shrink-0 rounded-full object-cover', className)}
      style={{ width: size, height: size }}
    />
  );
}
