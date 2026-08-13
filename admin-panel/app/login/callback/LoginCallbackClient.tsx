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
    const finish = async () => {
      if (!supabase) {
        setMessage('Supabase env vars are missing.');
        return;
      }

      const code = searchParams.get('code');
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error) {
          setMessage(error.message);
          return;
        }
      }

      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (!token) {
        setMessage('No session found after OAuth redirect.');
        return;
      }

      localStorage.setItem('adminToken', token);

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';
      const response = await fetch(`${apiBaseUrl}/admin/me`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        localStorage.removeItem('adminToken');
        setMessage('Unable to verify admin account.');
        return;
      }

      await response.json() as Promise<AdminProfile>;

      router.replace('/dashboard');
      router.refresh();
    };

    void finish();
  }, [router, searchParams]);

  return (
    <main className="min-h-screen bg-slate-950 text-white flex items-center justify-center">
      <p className="text-sm text-white/70">{message}</p>
    </main>
  );
}
