import { Suspense } from 'react';
import LoginCallbackClient from './LoginCallbackClient';

export default function LoginCallbackPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-slate-950 text-white flex items-center justify-center">
          <p className="text-sm text-white/70">Completing sign in...</p>
        </main>
      }
    >
      <LoginCallbackClient />
    </Suspense>
  );
}
