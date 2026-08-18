'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { supabase } from '../../lib/supabase';

type AdminProfile = {
  id: string;
  email: string;
};

export default function LoginCallbackClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [message, setMessage] = useState('Completing sign in...');

  useEffect(() => {
    console.log('[AUTH DEBUG 1] LoginCallbackClient mounted');
    console.log('[AUTH DEBUG 1] Current URL:', window.location.href);

    const finish = async () => {
      const showDebug = (text: string) => {
        console.log('[AUTH DEBUG]', text);
        setMessage(`AUTH DEBUG\n${text}`);
      };

      showDebug(`Callback page loaded\nURL: ${window.location.href}`);

      if (!supabase) {
        showDebug('ERROR: Supabase env vars are missing.');
        return;
      }

      const code = searchParams.get('code');
      showDebug(`OAuth code: ${code ? 'PRESENT' : 'MISSING'}`);

      if (code) {
        showDebug('Step 1: Exchanging OAuth code for Supabase session...');
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error) {
          showDebug(`ERROR during code exchange: ${error.message}`);
          return;
        }
        showDebug('Step 1 SUCCESS: OAuth code exchanged.');
      }

      showDebug('Step 2: Reading Supabase session...');
      const { data, error: sessionError } = await supabase.auth.getSession();

      if (sessionError) {
        showDebug(`ERROR reading session: ${sessionError.message}`);
        return;
      }

      const token = data.session?.access_token;
      showDebug(`Step 2 result: Session ${data.session ? 'FOUND' : 'NOT FOUND'}\nAccess token: ${token ? 'PRESENT' : 'MISSING'}`);

      if (!token) {
        showDebug('STOP: No session found after OAuth redirect.');
        return;
      }

      localStorage.setItem('adminToken', token);
      showDebug('Step 3: adminToken stored in localStorage.');

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';
      showDebug(`Step 4: Checking admin permission...\nAPI: ${apiBaseUrl}/admin/me`);

      try {
        const response = await fetch(`${apiBaseUrl}/admin/me`, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });

        showDebug(`Step 4 result: /admin/me returned HTTP ${response.status}`);

        if (!response.ok) {
          localStorage.removeItem('adminToken');
          showDebug(`ACCESS DENIED: User is not an admin.\nHTTP status: ${response.status}\nRedirect to dashboard will NOT happen.`);
          return;
        }

        const profile = await response.json() as AdminProfile;
        showDebug(`ADMIN VERIFIED: ${profile.email}\nStep 5: Redirecting to /dashboard...`);

        router.replace('/dashboard');
        router.refresh();
      } catch (error) {
        localStorage.removeItem('adminToken');
        showDebug(`ERROR calling /admin/me: ${error instanceof Error ? error.message : String(error)}`);
      }
    };

    void finish();
  }, [router, searchParams]);

  return (
    <main className="min-h-screen bg-slate-950 text-white flex items-center justify-center p-6">
      <pre className="whitespace-pre-wrap text-sm text-white/80 max-w-2xl w-full rounded-lg bg-white/5 p-5 border border-white/10">
        {message}
      </pre>
    </main>
  );
}
