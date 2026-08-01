import { redirect } from 'next/navigation';

/** The panel has no marketing root; send visitors straight to the dashboard. */
export default function RootPage() {
  redirect('/dashboard');
}
