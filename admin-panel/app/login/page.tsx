'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../lib/supabase';
import { Loader2, Shield, Trophy } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleLogin = async () => {
    if (!supabase) {
      setError('Supabase environment variables are not configured.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const redirectTo =
        typeof window !== 'undefined'
          ? `${window.location.origin}/login/callback`
          : undefined;

      const { error: oauthError } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo,
        },
      });

      if (oauthError) {
        throw oauthError;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
      setLoading(false);
      router.refresh();
    }
  };

  return (
    <main className="min-h-screen bg-[radial-gradient(circle_at_top,rgba(139,92,246,0.25),transparent_35%),linear-gradient(180deg,#050816_0%,#0b1020_50%,#050816_100%)] text-white flex items-center justify-center px-4">
      <div className="w-full max-w-md rounded-3xl border border-white/10 bg-white/5 p-8 shadow-2xl shadow-purple-950/40 backdrop-blur-xl">
        <div className="mb-8 flex items-center gap-3">
          <div className="rounded-2xl bg-linear-to-br from-purple-500 to-cyan-400 p-3">
            <Trophy className="h-6 w-6 text-white" />
          </div>
          <div>
            <p className="text-xs uppercase tracking-[0.35em] text-cyan-300">ArenaHub Admin</p>
            <h1 className="text-2xl font-black">Secure Sign In</h1>
          </div>
        </div>

       <p className="mb-6 text-sm leading-6 text-white/70">
  Sign in with your Google account. Only the authorized admin email can access the control panel.
</p>

        {error ? (
          <div className="mb-4 rounded-2xl border border-red-400/30 bg-red-500/10 p-4 text-sm text-red-100">
            {error}
          </div>
        ) : null}

        <button
          type="button"
          onClick={handleLogin}
          disabled={loading}
          className="flex w-full items-center justify-center gap-3 rounded-2xl bg-linear-to-r from-purple-500 to-cyan-400 px-4 py-3 font-semibold text-white transition hover:scale-[1.01] disabled:cursor-not-allowed disabled:opacity-70"
        >
          {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : <Shield className="h-5 w-5" />}
          Continue with Google
        </button>

       <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4 text-xs leading-5 text-white/60">
  Only the Google account configured as the admin email in the backend can access this panel.
</div>
      </div>
    </main>
  );
}
