'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout' ;
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

  if (error) {
    return (
      <Layout title="Dashboard" subtitle="Overview of your platform">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-800">
          {error}
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Dashboard" subtitle="Overview of your tournament platform">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
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

      {/* Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Quick Links */}
        <div className="bg-white rounded-lg shadow-sm p-6 border border-gray-200">
          <h2 className="text-lg font-bold text-gray-900 mb-4">Quick Actions</h2>
          <div className="space-y-2">
            <Link href="/tournaments/new" className="block px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition">
              Create Tournament
            </Link>
            <Link href="/users" className="block px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition">
              Manage Users
            </Link>
            <Link href="/registrations" className="block px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition">
              View Registrations
            </Link>
          </div>
        </div>

        {/* Registration Policy */}
        <div className="bg-white rounded-lg shadow-sm p-6 border border-gray-200">
          <h2 className="text-lg font-bold text-gray-900 mb-4">Registration Policy</h2>
          <p className="text-gray-600 text-sm mb-4">
            Choose whether tournaments use individual player ads or captain ads for registration.
          </p>
          <select className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600">
            <option value="individual_ads">Individual Ads (each player watches 1)</option>
            <option value="captain_ads">Captain Ads (captain watches all)</option>
          </select>
          <p className="text-xs text-gray-500 mt-2">Changes apply to new registrations only</p>
        </div>
      </div>

      {/* Recent Activities */}
      <div className="mt-8 bg-white rounded-lg shadow-sm p-6 border border-gray-200">
        <h2 className="text-lg font-bold text-gray-900 mb-4">Recent Activities</h2>
        <div className="space-y-3">
          <div className="flex items-center justify-between py-2 border-b border-gray-200">
            <div>
              <p className="text-gray-900 font-medium">New Tournament Created</p>
              <p className="text-sm text-gray-500">Summer Championship</p>
            </div>
            <span className="text-xs text-gray-500">2 hours ago</span>
          </div>
          <div className="flex items-center justify-between py-2 border-b border-gray-200">
            <div>
              <p className="text-gray-900 font-medium">Team Registered</p>
              <p className="text-sm text-gray-500">Team Alpha for Tournament</p>
            </div>
            <span className="text-xs text-gray-500">5 hours ago</span>
          </div>
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="text-gray-900 font-medium">New User Joined</p>
              <p className="text-sm text-gray-500">5 new players registered</p>
            </div>
            <span className="text-xs text-gray-500">1 day ago</span>
          </div>
        </div>
      </div>
    </Layout>
  );
}