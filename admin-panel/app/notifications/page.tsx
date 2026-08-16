'use client';

import { FormEvent, useState } from 'react';
import { Bell, CheckCircle2, Send, Users } from 'lucide-react';
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
            params: {
              title: title.trim(),
              body: body.trim(),
            },
          })
        : await apiClient.post('/notifications/admin/notify', null, {
            params: {
              target_user_id: targetUserId.trim(),
              title: title.trim(),
              body: body.trim(),
            },
          });

      if (broadcast) {
        setMessage(
          `Broadcast created for ${response.data?.recipients ?? 0} active user(s). ${response.data?.push_targets ?? 0} active device target(s) found.`,
        );
      } else {
        setMessage(
          `Notification created. ${response.data?.push_targets ?? 0} active device target(s) found.`,
        );
      }

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
        <div className="mb-5 flex items-start gap-3">
          <div className="rounded-2xl bg-purple-500/15 p-3 text-purple-300">
            <Bell size={22} />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white sm:text-2xl">Notification Generator</h2>
            <p className="mt-1 text-sm text-white/55">
              Send an in-app notification and best-effort FCM push to one user or every active user.
            </p>
          </div>
        </div>

        <form
          onSubmit={submit}
          className="rounded-2xl border border-white/10 bg-white/[0.04] p-4 shadow-xl sm:p-6"
        >
          <div className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <button
              type="button"
              onClick={() => setBroadcast(false)}
              className={`flex items-center gap-3 rounded-xl border px-4 py-3 text-left transition ${
                !broadcast
                  ? 'border-purple-400/60 bg-purple-500/10 text-white'
                  : 'border-white/10 bg-black/10 text-white/60'
              }`}
            >
              <Bell size={18} />
              <span>
                <span className="block text-sm font-semibold">Targeted</span>
                <span className="block text-xs text-white/45">One user</span>
              </span>
            </button>

            <button
              type="button"
              onClick={() => setBroadcast(true)}
              className={`flex items-center gap-3 rounded-xl border px-4 py-3 text-left transition ${
                broadcast
                  ? 'border-purple-400/60 bg-purple-500/10 text-white'
                  : 'border-white/10 bg-black/10 text-white/60'
              }`}
            >
              <Users size={18} />
              <span>
                <span className="block text-sm font-semibold">Broadcast</span>
                <span className="block text-xs text-white/45">All active users</span>
              </span>
            </button>
          </div>

          <div className="space-y-4">
            {!broadcast && (
              <label className="block">
                <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-white/55">
                  Target user ID
                </span>
                <input
                  value={targetUserId}
                  onChange={(event) => setTargetUserId(event.target.value)}
                  placeholder="User UUID"
                  className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition placeholder:text-white/30 focus:border-purple-400/70"
                />
              </label>
            )}

            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-white/55">
                Title
              </span>
              <input
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                maxLength={120}
                placeholder="Tournament update"
                className="w-full rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition placeholder:text-white/30 focus:border-purple-400/70"
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
                className="w-full resize-y rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-sm text-white outline-none transition placeholder:text-white/30 focus:border-purple-400/70"
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
            {loading ? 'Sending...' : broadcast ? 'Broadcast Notification' : 'Send Notification'}
          </button>
        </form>
      </div>
    </Layout>
  );
}
