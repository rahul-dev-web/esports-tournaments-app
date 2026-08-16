'use client';

import { FormEvent, useState } from 'react';
import { Bell, CheckCircle2, Send } from 'lucide-react';
import apiClient from '../lib/api';

export default function NotificationsPage() {
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

    if (!targetUserId.trim() || !title.trim() || !body.trim()) {
      setError('User ID, title and message are required.');
      return;
    }

    try {
      setLoading(true);
      const response = await apiClient.post('/notifications/admin/notify', null, {
        params: {
          target_user_id: targetUserId.trim(),
          title: title.trim(),
          body: body.trim(),
        },
      });

      setMessage(
        `Notification created. ${response.data?.push_targets ?? 0} active device target(s) found.`,
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
    <main className="mx-auto w-full max-w-3xl px-3 py-4 sm:px-5 sm:py-6">
      <div className="mb-5 flex items-start gap-3">
        <div className="rounded-2xl bg-purple-500/15 p-3 text-purple-300">
          <Bell size={22} />
        </div>
        <div>
          <h1 className="text-xl font-bold text-white sm:text-2xl">Notifications</h1>
          <p className="mt-1 text-sm text-white/55">
            Send an in-app notification and best-effort FCM push to a user.
          </p>
        </div>
      </div>

      <form onSubmit={submit} className="rounded-2xl border border-white/10 bg-white/[0.04] p-4 shadow-xl sm:p-6">
        <div className="space-y-4">
          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-white/55">
              Target user ID
            </span>
            <input
              value={targetUserId}
              onChange={(event) => setTargetUserId(event.target.value)}
              placeholder="User UUID"
              className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition focus:border-purple-400/70"
            />
          </label>

          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-white/55">
              Title
            </span>
            <input
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              maxLength={120}
              placeholder="Tournament update"
              className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition focus:border-purple-400/70"
            />
          </label>

          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-white/55">
              Message
            </span>
            <textarea
              value={body}
              onChange={(event) => setBody(event.target.value)}
              maxLength={500}
              rows={5}
              placeholder="Write the notification message..."
              className="w-full resize-y rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition focus:border-purple-400/70"
            />
          </label>
        </div>

        {message && (
          <div className="mt-4 flex items-start gap-2 rounded-xl border border-emerald-400/20 bg-emerald-400/10 px-3 py-3 text-sm text-emerald-200">
            <CheckCircle2 size={18} className="mt-0.5 shrink-0" />
            <span>{message}</span>
          </div>
        )}

        {error && (
          <div className="mt-4 rounded-xl border border-red-400/20 bg-red-400/10 px-3 py-3 text-sm text-red-200">
            {error}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="mt-5 flex w-full items-center justify-center gap-2 rounded-xl bg-purple-600 px-4 py-3 text-sm font-semibold text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <Send size={17} />
          {loading ? 'Sending...' : 'Send Notification'}
        </button>
      </form>
    </main>
  );
}
