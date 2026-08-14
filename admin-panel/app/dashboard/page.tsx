'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import StatsCard from '../components/StatsCard';
import {
  Trophy,
  Users,
  Users2,
  FileText,
} from 'lucide-react';
import Link from 'next/link';
import { DashboardStats } from '../lib/types';
import { adminAPI } from '../lib/api';

type RegistrationPolicy =
  | 'individual_ads'
  | 'captain_ads';

type RecentActivity = {
  id: string;
  type: 'user' | 'team' | 'tournament' | 'registration' | string;
  title: string;
  description: string;
  created_at: string;
};

const DEFAULT_REGISTRATION_POLICY: RegistrationPolicy =
  'individual_ads';

function formatRelativeTime(value: string): string {
  const createdAt = new Date(value).getTime();

  if (Number.isNaN(createdAt)) {
    return 'Recently';
  }

  const now = Date.now();
  const diffMs = Math.max(0, now - createdAt);

  const seconds = Math.floor(diffMs / 1000);

  if (seconds < 60) {
    return 'Just now';
  }

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) {
    return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
  }

  const hours = Math.floor(minutes / 60);

  if (hours < 24) {
    return `${hours} hour${hours === 1 ? '' : 's'} ago`;
  }

  const days = Math.floor(hours / 24);

  if (days < 7) {
    return `${days} day${days === 1 ? '' : 's'} ago`;
  }

  const weeks = Math.floor(days / 7);

  if (weeks < 5) {
    return `${weeks} week${weeks === 1 ? '' : 's'} ago`;
  }

  const date = new Date(value);

  return date.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    total_users: 0,
    total_teams: 0,
    total_registrations: 0,
    active_tournaments: 0,
  });

  const [recentActivities, setRecentActivities] =
    useState<RecentActivity[]>([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [registrationPolicy, setRegistrationPolicy] =
    useState<RegistrationPolicy>(
      DEFAULT_REGISTRATION_POLICY
    );

  const [policyLoading, setPolicyLoading] = useState(true);
  const [policySaving, setPolicySaving] = useState(false);
  const [policyMessage, setPolicyMessage] = useState<
    string | null
  >(null);
  const [policyError, setPolicyError] = useState<
    string | null
  >(null);

  useEffect(() => {
    let mounted = true;

    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [dashboardData, settingData] =
          await Promise.all([
            adminAPI.getDashboard(),
            adminAPI.getSetting('registration_policy'),
          ]);

        if (!mounted) {
          return;
        }

        setStats({
          total_users: Number(
            dashboardData?.total_users ?? 0
          ),
          total_teams: Number(
            dashboardData?.total_teams ?? 0
          ),
          total_registrations: Number(
            dashboardData?.total_registrations ?? 0
          ),
          active_tournaments: Number(
            dashboardData?.active_tournaments ?? 0
          ),
        });

        const activities = Array.isArray(
          dashboardData?.recent_activities
        )
          ? dashboardData.recent_activities
          : [];

        setRecentActivities(
          activities.filter(
            (activity: RecentActivity) =>
              activity &&
              typeof activity.id === 'string' &&
              typeof activity.title === 'string' &&
              typeof activity.description === 'string' &&
              typeof activity.created_at === 'string'
          )
        );

        const backendPolicy =
          settingData?.value;

        if (
          backendPolicy === 'individual_ads' ||
          backendPolicy === 'captain_ads'
        ) {
          setRegistrationPolicy(backendPolicy);
        } else {
          setRegistrationPolicy(
            DEFAULT_REGISTRATION_POLICY
          );
        }

        setPolicyError(null);
      } catch (err) {
        console.error(
          'Error fetching admin dashboard data:',
          err
        );

        if (!mounted) {
          return;
        }

        setError(
          'Failed to load dashboard data. Please try again.'
        );

        setRecentActivities([]);

        setRegistrationPolicy(
          DEFAULT_REGISTRATION_POLICY
        );

        setPolicyError(
          'Unable to load the current registration policy.'
        );
      } finally {
        if (mounted) {
          setLoading(false);
          setPolicyLoading(false);
        }
      }
    };

    fetchDashboardData();

    return () => {
      mounted = false;
    };
  }, []);

  const handleRegistrationPolicyChange = async (
    event: React.ChangeEvent<HTMLSelectElement>
  ) => {
    const newPolicy =
      event.target.value as RegistrationPolicy;

    if (
      newPolicy !== 'individual_ads' &&
      newPolicy !== 'captain_ads'
    ) {
      return;
    }

    const previousPolicy = registrationPolicy;

    setRegistrationPolicy(newPolicy);
    setPolicySaving(true);
    setPolicyMessage(null);
    setPolicyError(null);

    try {
      await adminAPI.updateSetting(
        'registration_policy',
        {
          key: 'registration_policy',
          value: newPolicy,
          description:
            'Registration ad policy used for new tournament registrations.',
          value_type: 'string',
        }
      );

      setPolicyMessage(
        'Registration policy updated successfully.'
      );
    } catch (err) {
      console.error(
        'Error updating registration policy:',
        err
      );

      setRegistrationPolicy(previousPolicy);

      setPolicyError(
        'Failed to update registration policy. Please try again.'
      );
    } finally {
      setPolicySaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout
        title="Dashboard"
        subtitle="Overview of your tournament platform"
      >
        {error ? (
          <div className="mb-6 flex items-center justify-between rounded-2xl border border-red-400/30 bg-red-500/10 p-4 text-red-100">
            <span>{error}</span>

            <button
              type="button"
              onClick={() =>
                window.location.reload()
              }
              className="rounded-xl border border-red-300/20 bg-red-400/10 px-4 py-2 text-sm font-semibold text-red-100 transition hover:bg-red-400/20"
            >
              Retry
            </button>
          </div>
        ) : null}

        <div className="mb-8 grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-4">
          <StatsCard
            label="Total Users"
            value={
              loading
                ? '-'
                : stats.total_users
            }
            trend={12}
            icon={<Users size={24} />}
          />

          <StatsCard
            label="Total Teams"
            value={
              loading
                ? '-'
                : stats.total_teams
            }
            trend={8}
            icon={<Users2 size={24} />}
          />

          <StatsCard
            label="Registrations"
            value={
              loading
                ? '-'
                : stats.total_registrations
            }
            trend={15}
            icon={<FileText size={24} />}
          />

          <StatsCard
            label="Active Tournaments"
            value={
              loading
                ? '-'
                : stats.active_tournaments
            }
            trend={5}
            icon={<Trophy size={24} />}
          />
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <h2 className="text-lg font-bold text-white">
              Quick Actions
            </h2>

            <div className="mt-4 space-y-3">
              <Link
                href="/tournaments/new"
                className="block rounded-2xl bg-gradient-to-r from-violet-500 to-cyan-400 px-4 py-3 font-semibold text-white transition hover:opacity-95"
              >
                Create Tournament
              </Link>

              <Link
                href="/users"
                className="block rounded-2xl border border-white/10 bg-white/5 px-4 py-3 font-semibold text-white transition hover:bg-white/10"
              >
                Manage Users
              </Link>

              <Link
                href="/registrations"
                className="block rounded-2xl border border-white/10 bg-white/5 px-4 py-3 font-semibold text-white transition hover:bg-white/10"
              >
                View Registrations
              </Link>
            </div>
          </div>

          <div className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-lg font-bold text-white">
                  Registration Policy
                </h2>

                <p className="mt-3 text-sm text-white/70">
                  Choose whether tournaments use
                  individual player ads or captain ads
                  for registration.
                </p>
              </div>

              {policySaving ? (
                <span className="rounded-full border border-cyan-400/20 bg-cyan-400/10 px-3 py-1 text-xs font-medium text-cyan-200">
                  Saving...
                </span>
              ) : null}
            </div>

            <select
              value={registrationPolicy}
              onChange={
                handleRegistrationPolicyChange
              }
              disabled={
                policyLoading ||
                policySaving
              }
              className="mt-4 w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none ring-0 transition focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <option value="individual_ads">
                Individual Ads (each player watches 1)
              </option>

              <option value="captain_ads">
                Captain Ads (captain watches all)
              </option>
            </select>

            {policyLoading ? (
              <p className="mt-3 text-xs text-white/50">
                Loading current policy...
              </p>
            ) : policySaving ? (
              <p className="mt-3 text-xs text-cyan-200/70">
                Saving policy to the server...
              </p>
            ) : policyMessage ? (
              <p className="mt-3 text-xs text-emerald-300">
                {policyMessage}
              </p>
            ) : policyError ? (
              <p className="mt-3 text-xs text-red-300">
                {policyError}
              </p>
            ) : (
              <p className="mt-3 text-xs text-white/50">
                Changes apply to new registrations only
              </p>
            )}
          </div>
        </div>

        <div className="mt-8 rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-bold text-white">
                Recent Activities
              </h2>

              <p className="mt-1 text-sm text-white/50">
                Latest activity from the platform
              </p>
            </div>

            {loading ? (
              <span className="text-xs text-white/50">
                Loading...
              </span>
            ) : null}
          </div>

          <div className="mt-4 space-y-3">
            {!loading && recentActivities.length === 0 ? (
              <div className="rounded-2xl border border-white/10 bg-white/5 px-4 py-8 text-center">
                <p className="text-sm text-white/60">
                  No recent activities
                </p>
              </div>
            ) : null}

            {recentActivities.map((activity) => (
              <div
                key={activity.id}
                className="flex items-center justify-between gap-4 rounded-2xl border border-white/10 bg-white/5 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="font-medium text-white">
                    {activity.title}
                  </p>

                  <p className="truncate text-sm text-white/55">
                    {activity.description}
                  </p>
                </div>

                <span className="shrink-0 text-xs text-white/50">
                  {formatRelativeTime(
                    activity.created_at
                  )}
                </span>
              </div>
            ))}
          </div>
        </div>
      </Layout>
    </div>
  );
}
