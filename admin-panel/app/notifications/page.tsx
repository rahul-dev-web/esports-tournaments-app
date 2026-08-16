'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Bell, CheckCircle2, Home, Send, Users } from 'lucide-react';
import Layout from '../components/Layout';
import apiClient from '../lib/api';

export default function NotificationsPage() {
  const [broadcast, setBroadcast] = useState(false);
  const [targetUserId, setTargetUserId] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setMessage('');
    setError('');

    if (!title.trim() || !body.trim()) {
      setError('Title and message are required.');
      return;
    }

    if (!broadcast && !targetUserId.trim()) {
      setError('User ID is required for a targeted notification.');
      return;
    }

    try {
      setLoading(true);
      const response = broadcast
        ? await apiClient.post('/notifications/admin/broadcast', null, {
            params: { title: title.trim(), body: body.trim() },
          })
        : await apiClient.post('/notifications/admin/notify', null, {
            params: {
              target_user_id: targetUserId.trim(),
              title: title.trim(),
              body: body.trim(),
            },
          });

      setMessage(
        broadcast
          ? `Broadcast created for ${response.data?.recipients ?? 0} active user(s). ${response.data?.push_targets ?? 0} active device target(s) found.`
          : `Notification created. ${response.data?.push_targets ?? 0} active device target(s) found.`,
      );
      setTitle('');
      setBody('');
    } catch (requestError: any) {
      const detail = requestError?.response?.data?.detail;
      setError(typeof detail === 'string' ? detail : 'Unable to send notification.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout title="Notifications" subtitle="Send targeted or broadcast notifications">
      <div className="mx-auto w-full max-w-3xl">
        <div className="mb-3 flex items-center justify-between gap-2">
          <div className="flex min-w-0 items-center gap-2.5">
            <div className="shrink-0 rounded-xl bg-purple-500/15 p-2 text-purple-300">
              <Bell size={18} />
            </div>
            <div className="min-w-0">
              <h2 className="text-lg font-bold text-white sm:text-xl">Notification Generator</h2>
              <p className="hidden text-xs text-white/50 sm:block">Send to one user or all active users.</p>
            </div>
          </div>

          <div className="flex shrink-0 items-center gap-1.5">
            <Link href="/dashboard" aria-label="Dashboard" className="inline-flex items-center justify-center rounded-lg border border-white/10 bg-white/5 p-2 text-white/70 hover:bg-white/10 hover:text-white">
              <Home size={15} />
            </Link>
            <Link href="/settings" className="hidden rounded-lg border border-white/10 bg-white/5 px-2.5 py-1.5 text-xs font-medium text-white/70 hover:bg-white/10 hover:text-white sm:inline-flex">
              Settings
            </Link>
          </div>
        </div>

        <div className="mb-3">
          <Link href="/dashboard" className="inline-flex items-center gap-1.5 text-xs text-white/45 hover:text-white">
            <ArrowLeft size={14} />
            Back to dashboard
          </Link>
        </div>

        <form onSubmit={submit} className="rounded-xl border border-white/10 bg-white/[0.04] p-3 shadow-xl sm:p-5">
          {/* Keep Targeted and Broadcast side-by-side on mobile. */}
          <div className="mb-3 grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setBroadcast(false)}
              className={`flex min-w-0 items-center gap-2 rounded-lg border px-2.5 py-2 text-left transition sm:px-3 sm:py-2.5 ${
                !broadcast ? 'border-purple-400/60 bg-purple-500/10 text-white' : 'border-white/10 bg-black/10 text-white/60'
              }`}
            >
              <Bell size={16} className="shrink-0" />
              <span className="min-w-0">
                <span className="block truncate text-xs font-semibold sm:text-sm">Targeted</span>
                <span className="block truncate text-[10px] text-white/40 sm:text-xs">One user</span>
              </span>
            </button>

            <button
              type="button"
              onClick={() => setBroadcast(true)}
              className={`flex min-w-0 items-center gap-2 rounded-lg border px-2.5 py-2 text-left transition sm:px-3 sm:py-2.5 ${
                broadcast ? 'border-purple-400/60 bg-purple-500/10 text-white' : 'border-white/10 bg-black/10 text-white/60'
              }`}
            >
              <Users size={16} className="shrink-0" />
              <span className="min-w-0">
                <span className="block truncate text-xs font-semibold sm:text-sm">Broadcast</span>
                <span className="block truncate text-[10px] text-white/40 sm:text-xs">All active users</span>
              </span>
            </button>
          </div>

          <div className="space-y-3">
            {!broadcast && (
              <label className="block">
                <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-white/50">Target user ID</span>
                <input value={targetUserId} onChange={(event) => setTargetUserId(event.target.value)} placeholder="User UUID" className="w-full rounded-lg border border-white/10 bg-black/20 px-3 py-2.5 text-sm text-white outline-none placeholder:text-white/30 focus:border-purple-400/70" />
              </label>
            )}

            <label className="block">
              <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-white/50">Title</span>
              <input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={120} placeholder="Tournament update" className="w-full rounded-lg border border-white/10 bg-black/20 px-3 py-2.5 text-sm text-white outline-none placeholder:text-white/30 focus:border-purple-400/70" />
            </label>

            <label className="block">
              <span className="mb-1 block text-[11px] font-semibold uppercase tracking-wide text-white/50">Message</span>
              <textarea value={body} onChange={(event) => setBody(event.target.value)} maxLength={500} rows={4} placeholder="Write the notification message..." className="w-full resize-y rounded-lg border border-white/10 bg-black/20 px-3 py-2.5 text-sm text-white outline-none placeholder:text-white/30 focus:border-purple-400/70" />
            </label>
          </div>

          {message && (
            <div className="mt-3 flex items-start gap-2 rounded-lg border border-emerald-400/20 bg-emerald-400/10 px-3 py-2.5 text-xs text-emerald-200 sm:text-sm">
              <CheckCircle2 size={16} className="mt-0.5 shrink-0" />
              <span>{message}</span>
            </div>
          )}

          {error && <div className="mt-3 rounded-lg border border-red-400/20 bg-red-400/10 px-3 py-2.5 text-xs text-red-200 sm:text-sm">{error}</div>}

          <button type="submit" disabled={loading} className="mt-3 flex w-full items-center justify-center gap-2 rounded-lg bg-purple-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50">
            <Send size={16} />
            {loading ? 'Sending...' : broadcast ? 'Broadcast Notification' : 'Send Notification'}
          </button>
        </form>
      </div>
    </Layout>
  );
}
