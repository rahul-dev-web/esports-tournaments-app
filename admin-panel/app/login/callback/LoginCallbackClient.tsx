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
      console.group('[AUTH DEBUG] CALLBACK — STEP 4');
      console.log('Callback page mounted');
      console.log('Current URL:', window.location.href);
      console.log('Path:', window.location.pathname);
      console.log('Query string:', window.location.search);
      console.log('Hash:', window.location.hash || '(empty)');

      if (!supabase) {
        console.error('[AUTH DEBUG] Supabase client is missing on callback');
        console.groupEnd();
        setMessage('Login callback error. Check browser console.');
        return;
      }

      const code = searchParams.get('code');
      const oauthError = searchParams.get('error');
      const oauthErrorDescription = searchParams.get('error_description');

      console.log('[AUTH DEBUG] STEP 5 — OAuth callback parameters');
      console.log('OAuth code:', code ? 'PRESENT' : 'MISSING');
      console.log('OAuth error:', oauthError || 'NONE');
      console.log('OAuth error description:', oauthErrorDescription || 'NONE');

      if (oauthError) {
        console.error('[AUTH DEBUG] OAuth provider returned an error');
        console.groupEnd();
        setMessage('Google OAuth returned an error. Check browser console.');
        return;
      }

      if (code) {
        console.log('[AUTH DEBUG] STEP 6 — Exchanging OAuth code for Supabase session');
        const { data: exchangeData, error } = await supabase.auth.exchangeCodeForSession(code);
        console.log('Code exchange data:', exchangeData);
        console.log('Code exchange error:', error);

        if (error) {
          console.error('[AUTH DEBUG] Code exchange FAILED:', error.message);
          console.groupEnd();
          setMessage('Session exchange failed. Check browser console.');
          return;
        }

        console.log('[AUTH DEBUG] STEP 6 SUCCESS — OAuth code exchanged');
      } else {
        console.warn('[AUTH DEBUG] No OAuth code found. Checking existing session instead.');
      }

      console.log('[AUTH DEBUG] STEP 7 — Reading Supabase session');
      const { data, error: sessionError } = await supabase.auth.getSession();
      console.log('getSession error:', sessionError);
      console.log('Session found:', !!data.session);
      console.log('User ID:', data.session?.user?.id || 'NONE');
      console.log('User email:', data.session?.user?.email || 'NONE');
      console.log('User provider:', data.session?.user?.app_metadata?.provider || 'NONE');
      console.log('Access token:', data.session?.access_token ? 'PRESENT' : 'MISSING');

      if (sessionError) {
        console.error('[AUTH DEBUG] Session read failed:', sessionError.message);
        console.groupEnd();
        setMessage('Session read failed. Check browser console.');
        return;
      }

      const token = data.session?.access_token;
      if (!token) {
        console.error('[AUTH DEBUG] STOP — No Supabase access token after callback');
        console.groupEnd();
        setMessage('No Supabase session found. Check browser console.');
        return;
      }

      localStorage.setItem('adminToken', token);
      console.log('[AUTH DEBUG] STEP 8 — adminToken stored in localStorage');
      console.log('adminToken exists:', !!localStorage.getItem('adminToken'));

      const apiBaseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';
      console.log('[AUTH DEBUG] STEP 9 — Checking backend admin permission');
      console.log('API base URL:', apiBaseUrl);
      console.log('Endpoint:', `${apiBaseUrl}/admin/me`);

      try {
        const response = await fetch(`${apiBaseUrl}/admin/me`, {
          headers: { Authorization: `Bearer ${token}` },
        });

        console.log('[AUTH DEBUG] /admin/me response');
        console.log('HTTP status:', response.status);
        console.log('HTTP ok:', response.ok);
        console.log('Response URL:', response.url);

        const responseText = await response.text();
        console.log('Response body:', responseText);

        if (!response.ok) {
          localStorage.removeItem('adminToken');
          console.warn('[AUTH DEBUG] STEP 10 — ADMIN CHECK FAILED');
          console.warn('User is authenticated with Google but backend rejected admin access.');
          console.log('adminToken after removal:', !!localStorage.getItem('adminToken'));
          console.groupEnd();
          setMessage('Authenticated, but NOT an admin. Check browser console.');
          return;
        }

        let profile: AdminProfile;
        try {
          profile = JSON.parse(responseText) as AdminProfile;
        } catch {
          console.error('[AUTH DEBUG] Could not parse /admin/me response as JSON');
          console.groupEnd();
          setMessage('Admin response parsing failed. Check browser console.');
          return;
        }

        console.log('[AUTH DEBUG] STEP 10 SUCCESS — ADMIN VERIFIED');
        console.log('Admin profile:', profile);
        console.log('Verified admin email:', profile.email);
        console.log('[AUTH DEBUG] STEP 11 — Redirecting to /dashboard');

        console.groupEnd();
        router.replace('/dashboard');
        router.refresh();
      } catch (error) {
        localStorage.removeItem('adminToken');
        console.error('[AUTH DEBUG] Backend admin check threw an exception:', error);
        console.groupEnd();
        setMessage('Backend admin check failed. Check browser console.');
      }
    };

    void finish();
  }, [router, searchParams]);

  return (
    <main className="min-h-screen bg-slate-950 text-white flex items-center justify-center p-6">
      <div className="rounded-2xl border border-white/10 bg-white/5 p-6 text-sm text-white/70">
        {message}
      </div>
    </main>
  );
}
