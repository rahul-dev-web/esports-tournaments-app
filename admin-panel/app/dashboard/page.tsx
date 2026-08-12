'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import StatsCard from '../components/StatsCard';
import { Trophy, Users, Users2, FileText } from 'lucide-react';
import Link from 'next/link';
import { DashboardStats } from '../lib/types';
import {
  tournamentsAPI,
  usersAPI,
  teamsAPI,
} from '../lib/api';

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    total_users: 0,
    total_teams: 0,
    total_registrations: 0,
    active_tournaments: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        // Fetch data in parallel
        const [users, teams, tournaments] = await Promise.all([
          usersAPI.getAll(1, 1), // Get first page to get count
          teamsAPI.getAll(1, 1),
          tournamentsAPI.getAll(1, 1),
        ]);

        // Calculate stats
        setStats({
          total_users: users.length || 0,
          total_teams: teams.length || 0,
          total_registrations: 0, // Will calculate from tournaments
          active_tournaments: tournaments.filter((t: any) => t.status === 'published').length || 0,
        });
      } catch (err) {
        console.error('Error fetching stats:', err);
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout title="Dashboard" subtitle="Overview of your tournament platform">
        {error ? (
          <div className="rounded-2xl border border-red-400/30 bg-red-500/10 p-4 text-red-100">
            {error}
          </div>
        ) : null}

        <div className="grid grid-cols-1 gap-6 mb-8 md:grid-cols-2 xl:grid-cols-4">
          <StatsCard
            label="Total Users"
            value={loading ? '-' : stats.total_users}
            trend={12}
            icon={<Users size={24} />}
          />
          <StatsCard
            label="Total Teams"
            value={loading ? '-' : stats.total_teams}
            trend={8}
            icon={<Users2 size={24} />}
          />
          <StatsCard
            label="Registrations"
            value={loading ? '-' : stats.total_registrations}
            trend={15}
            icon={<FileText size={24} />}
          />
          <StatsCard
            label="Active Tournaments"
            value={loading ? '-' : stats.active_tournaments}
            trend={5}
            icon={<Trophy size={24} />}
          />
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <h2 className="text-lg font-bold text-white">Quick Actions</h2>
            <div className="mt-4 space-y-3">
              <Link href="/tournaments/new" className="block rounded-2xl bg-gradient-to-r from-violet-500 to-cyan-400 px-4 py-3 font-semibold text-white transition hover:opacity-95">
                Create Tournament
              </Link>
              <Link href="/users" className="block rounded-2xl border border-white/10 bg-white/5 px-4 py-3 font-semibold text-white transition hover:bg-white/10">
                Manage Users
              </Link>
              <Link href="/registrations" className="block rounded-2xl border border-white/10 bg-white/5 px-4 py-3 font-semibold text-white transition hover:bg-white/10">
                View Registrations
              </Link>
            </div>
          </div>

          <div className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <h2 className="text-lg font-bold text-white">Registration Policy</h2>
            <p className="mt-3 text-sm text-white/70">
              Choose whether tournaments use individual player ads or captain ads for registration.
            </p>
            <select className="mt-4 w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none ring-0 focus:border-cyan-400">
              <option value="individual_ads">Individual Ads (each player watches 1)</option>
              <option value="captain_ads">Captain Ads (captain watches all)</option>
            </select>
            <p className="mt-3 text-xs text-white/50">Changes apply to new registrations only</p>
          </div>
        </div>

        <div className="mt-8 rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
          <h2 className="text-lg font-bold text-white">Recent Activities</h2>
          <div className="mt-4 space-y-3">
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <div>
                <p className="font-medium text-white">New Tournament Created</p>
                <p className="text-sm text-white/55">Summer Championship</p>
              </div>
              <span className="text-xs text-white/50">2 hours ago</span>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <div>
                <p className="font-medium text-white">Team Registered</p>
                <p className="text-sm text-white/55">Team Alpha for Tournament</p>
              </div>
              <span className="text-xs text-white/50">5 hours ago</span>
            </div>
            <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-white/5 px-4 py-3">
              <div>
                <p className="font-medium text-white">New User Joined</p>
                <p className="text-sm text-white/55">5 new players registered</p>
              </div>
              <span className="text-xs text-white/50">1 day ago</span>
            </div>
          </div>
        </div>
      </Layout>
    </div>
  );
}
