'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import StatsCard from '../components/StatsCard';
import { Trophy, Users, Users2, FileText } from 'lucide-react';
import Link from 'next/link';
import { DashboardStats } from '../lib/types';
import { adminAPI } from '../lib/api';

type RegistrationPolicy = 'individual_ads' | 'captain_ads';
type RecentActivity = { id: string; type: 'user' | 'team' | 'tournament' | 'registration' | string; title: string; description: string; created_at: string };
const DEFAULT_REGISTRATION_POLICY: RegistrationPolicy = 'individual_ads';

function createEmptyDashboardStats(): DashboardStats {
  return { total_users: 0, total_teams: 0, total_registrations: 0, active_tournaments: 0, recent_activities: [] };
}

function formatRelativeTime(value: string): string {
  const createdAt = new Date(value).getTime();
  if (Number.isNaN(createdAt)) return 'Recently';
  const seconds = Math.floor(Math.max(0, Date.now() - createdAt) / 1000);
  if (seconds < 60) return 'Just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;
  const weeks = Math.floor(days / 7);
  if (weeks < 5) return `${weeks} week${weeks === 1 ? '' : 's'} ago`;
  return new Date(value).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>(createEmptyDashboardStats);
  const [recentActivities, setRecentActivities] = useState<RecentActivity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [registrationPolicy, setRegistrationPolicy] = useState<RegistrationPolicy>(DEFAULT_REGISTRATION_POLICY);
  const [policyLoading, setPolicyLoading] = useState(true);
  const [policySaving, setPolicySaving] = useState(false);
  const [policyMessage, setPolicyMessage] = useState<string | null>(null);
  const [policyError, setPolicyError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    const fetchDashboardData = async () => {
      console.group('[AUTH DEBUG] DASHBOARD — STEP 12');
      console.log('Dashboard mounted');
      console.log('Current URL:', window.location.href);
      console.log('Stored adminToken:', localStorage.getItem('adminToken') ? 'PRESENT' : 'MISSING');
      console.log('API base URL:', process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api');

      try {
        setLoading(true); setError(null);
        console.log('[AUTH DEBUG] STEP 13 — Calling dashboard APIs');
        const [dashboardData, settingData] = await Promise.all([adminAPI.getDashboard(), adminAPI.getSetting('registration_policy')]);
        console.log('[AUTH DEBUG] Dashboard API SUCCESS');
        console.log('Dashboard response:', dashboardData);
        console.log('Settings response:', settingData);
        if (!mounted) return;
        const activities = Array.isArray(dashboardData?.recent_activities) ? dashboardData.recent_activities : [];
        setStats({
          total_users: Number(dashboardData?.total_users ?? 0),
          total_teams: Number(dashboardData?.total_teams ?? 0),
          total_registrations: Number(dashboardData?.total_registrations ?? 0),
          active_tournaments: Number(dashboardData?.active_tournaments ?? 0),
          pending_registrations: Number(dashboardData?.pending_registrations ?? 0),
          recent_activities: activities,
        });
        setRecentActivities(activities.filter((activity: RecentActivity) => activity && typeof activity.id === 'string' && typeof activity.title === 'string' && typeof activity.description === 'string' && typeof activity.created_at === 'string'));
        const backendPolicy = settingData?.value;
        setRegistrationPolicy(backendPolicy === 'individual_ads' || backendPolicy === 'captain_ads' ? backendPolicy : DEFAULT_REGISTRATION_POLICY);
        setPolicyError(null);
        console.log('[AUTH DEBUG] STEP 14 — Dashboard data loaded successfully');
      } catch (err) {
        console.error('[AUTH DEBUG] Dashboard API FAILED:', err);
        if (!mounted) return;
        setError('Failed to load dashboard data. Please try again.'); setStats(createEmptyDashboardStats()); setRecentActivities([]); setRegistrationPolicy(DEFAULT_REGISTRATION_POLICY); setPolicyError('Unable to load the current registration policy.');
      } finally {
        if (mounted) { setLoading(false); setPolicyLoading(false); }
        console.groupEnd();
      }
    };
    fetchDashboardData();
    return () => { mounted = false; };
  }, []);

  const handleRegistrationPolicyChange = async (event: React.ChangeEvent<HTMLSelectElement>) => {
    const newPolicy = event.target.value as RegistrationPolicy;
    if (newPolicy !== 'individual_ads' && newPolicy !== 'captain_ads') return;
    const previousPolicy = registrationPolicy;
    setRegistrationPolicy(newPolicy); setPolicySaving(true); setPolicyMessage(null); setPolicyError(null);
    try {
      await adminAPI.updateSetting('registration_policy', { key: 'registration_policy', value: newPolicy, description: 'Registration ad policy used for new tournament registrations.', value_type: 'string' });
      setPolicyMessage('Registration policy updated successfully.');
    } catch (err) {
      console.error('Error updating registration policy:', err); setRegistrationPolicy(previousPolicy); setPolicyError('Failed to update registration policy. Please try again.');
    } finally { setPolicySaving(false); }
  };

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout title="Dashboard" subtitle="Overview of your tournament platform">
        {error ? <div className="mb-4 flex items-center justify-between gap-3 rounded-2xl border border-red-400/30 bg-red-500/10 p-3 text-sm text-red-100 sm:mb-6 sm:p-4"><span>{error}</span><button type="button" onClick={() => window.location.reload()} className="shrink-0 rounded-xl border border-red-300/20 bg-red-400/10 px-3 py-1.5 text-xs font-semibold text-red-100 transition hover:bg-red-400/20 sm:px-4 sm:py-2 sm:text-sm">Retry</button></div> : null}

        <div className="mb-4 grid grid-cols-2 gap-2 sm:mb-8 sm:gap-6 md:grid-cols-2 xl:grid-cols-4">
          <StatsCard label="Total Users" value={loading ? '-' : stats.total_users} trend={12} icon={<Users size={24} />} />
          <StatsCard label="Total Teams" value={loading ? '-' : stats.total_teams} trend={8} icon={<Users2 size={24} />} />
          <StatsCard label="Registrations" value={loading ? '-' : stats.total_registrations} trend={15} icon={<FileText size={24} />} />
          <StatsCard label="Active Tournaments" value={loading ? '-' : stats.active_tournaments} trend={5} icon={<Trophy size={24} />} />
        </div>

        <div className="grid grid-cols-1 gap-3 lg:grid-cols-2 lg:gap-6">
          <div className="rounded-2xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur-xl sm:rounded-[28px] sm:p-6 sm:shadow-2xl">
            <h2 className="text-base font-bold text-white sm:text-lg">Quick Actions</h2>
            <div className="mt-3 space-y-2 sm:mt-4 sm:space-y-3">
              <Link href="/tournaments/new" className="block rounded-xl bg-gradient-to-r from-violet-500 to-cyan-400 px-3 py-2.5 text-sm font-semibold text-white transition hover:opacity-95 sm:rounded-2xl sm:px-4 sm:py-3">Create Tournament</Link>
              <Link href="/users" className="block rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10 sm:rounded-2xl sm:px-4 sm:py-3">Manage Users</Link>
              <Link href="/registrations" className="block rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10 sm:rounded-2xl sm:px-4 sm:py-3">View Registrations</Link>
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur-xl sm:rounded-[28px] sm:p-6 sm:shadow-2xl">
            <div className="flex items-start justify-between gap-3"><div><h2 className="text-base font-bold text-white sm:text-lg">Registration Policy</h2><p className="mt-2 text-xs leading-5 text-white/70 sm:mt-3 sm:text-sm">Choose whether tournaments use individual player ads or captain ads for registration.</p></div>{policySaving ? <span className="shrink-0 rounded-full border border-cyan-400/20 bg-cyan-400/10 px-2 py-1 text-[10px] font-medium text-cyan-200 sm:px-3 sm:text-xs">Saving...</span> : null}</div>
            <select value={registrationPolicy} onChange={handleRegistrationPolicyChange} disabled={policyLoading || policySaving} className="mt-3 w-full rounded-xl border border-white/10 bg-[#0d152b] px-3 py-2.5 text-sm text-white outline-none transition focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60 sm:mt-4 sm:rounded-2xl sm:px-4 sm:py-3"><option value="individual_ads">Individual Ads (each player watches 1)</option><option value="captain_ads">Captain Ads (captain watches all)</option></select>
            {policyLoading ? <p className="mt-2 text-[11px] text-white/50 sm:mt-3 sm:text-xs">Loading current policy...</p> : policySaving ? <p className="mt-2 text-[11px] text-cyan-200/70 sm:mt-3 sm:text-xs">Saving policy to the server...</p> : policyMessage ? <p className="mt-2 text-[11px] text-emerald-300 sm:mt-3 sm:text-xs">{policyMessage}</p> : policyError ? <p className="mt-2 text-[11px] text-red-300 sm:mt-3 sm:text-xs">{policyError}</p> : <p className="mt-2 text-[11px] text-white/50 sm:mt-3 sm:text-xs">Changes apply to new registrations only</p>}
          </div>
        </div>

        <div className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-4 shadow-xl backdrop-blur-xl sm:mt-8 sm:rounded-[28px] sm:p-6 sm:shadow-2xl">
          <div className="flex items-center justify-between gap-3"><div><h2 className="text-base font-bold text-white sm:text-lg">Recent Activities</h2><p className="mt-0.5 text-xs text-white/50 sm:mt-1 sm:text-sm">Latest activity from the platform</p></div>{loading ? <span className="text-[11px] text-white/50 sm:text-xs">Loading...</span> : null}</div>
          <div className="mt-3 space-y-2 sm:mt-4 sm:space-y-3">
            {!loading && recentActivities.length === 0 ? <div className="rounded-xl border border-white/10 bg-white/5 px-3 py-5 text-center sm:rounded-2xl sm:px-4 sm:py-8"><p className="text-xs text-white/60 sm:text-sm">No recent activities</p></div> : null}
            {recentActivities.map((activity) => <div key={activity.id} className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/5 px-3 py-2.5 sm:rounded-2xl sm:px-4 sm:py-3"><div className="min-w-0"><p className="text-sm font-medium text-white">{activity.title}</p><p className="truncate text-xs text-white/55 sm:text-sm">{activity.description}</p></div><span className="shrink-0 text-[10px] text-white/50 sm:text-xs">{formatRelativeTime(activity.created_at)}</span></div>)}
          </div>
        </div>
      </Layout>
    </div>
  );
}
