'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { teamsAPI } from '../lib/api';
import { Users2, Lock, Globe, RefreshCw } from 'lucide-react';

type Team = {
  id: string;
  name: string;
  game: string;
  captain_id: string;
  member_count: number;
  is_private: boolean;
  logo_url?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

type TeamsResponse = {
  total: number;
  skip: number;
  limit: number;
  teams: Team[];
};

export default function TeamsPage() {
  const [teams, setTeams] = useState<Team[]>([]);
  const [totalTeams, setTotalTeams] = useState(0);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);

  const limit = 10;

  const fetchTeams = useCallback(async () => {
    try {
      setError(null);
      const data = await teamsAPI.getAll(page, limit);

      if (Array.isArray(data)) {
        setTeams(data);
        setTotalTeams(data.length);
        return;
      }

      const response = data as TeamsResponse;
      const teamList = Array.isArray(response?.teams) ? response.teams : [];
      setTeams(teamList);
      setTotalTeams(typeof response?.total === 'number' ? response.total : teamList.length);
    } catch (err) {
      console.error('Error fetching teams:', err);
      setError('Failed to load teams. Please try again.');
      setTeams([]);
      setTotalTeams(0);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [page]);

  useEffect(() => {
    setLoading(true);
    fetchTeams();
  }, [fetchTeams]);

  const handleRefresh = async () => {
    setRefreshing(true);
    await fetchTeams();
  };

  const formatDate = (value?: string | null) => {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '—';
    return date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  };

  const totalPages = Math.max(1, Math.ceil(totalTeams / limit));
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return (
    <Layout title="Teams" subtitle="Manage all registered teams">
      <div className="mb-4 flex flex-col gap-3 sm:mb-6 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
        <div className="min-w-0">
          <h2 className="text-base font-semibold text-gray-900 sm:text-lg">Team Management</h2>
          <p className="mt-1 text-xs leading-5 text-gray-500 sm:text-sm">
            View teams created by players and their current membership details.
          </p>
        </div>
        <button type="button" onClick={handleRefresh} disabled={refreshing || loading}
          className="inline-flex w-full items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto sm:px-4">
          <RefreshCw size={15} className={refreshing ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      {error && (
        <div className="mb-4 flex items-start justify-between gap-3 rounded-lg border border-red-200 bg-red-50 px-3 py-3 text-xs text-red-700 sm:mb-6 sm:px-4 sm:text-sm">
          <span>{error}</span>
          <button type="button" onClick={handleRefresh} className="shrink-0 font-medium underline hover:no-underline">Retry</button>
        </div>
      )}

      <div className="mb-3 flex items-center justify-between sm:mb-4">
        <p className="text-xs text-gray-500 sm:text-sm">{totalTeams} {totalTeams === 1 ? 'team' : 'teams'} total</p>
        {totalTeams > 0 && <p className="text-xs text-gray-500 sm:text-sm">Showing {(page - 1) * limit + 1}–{Math.min(page * limit, totalTeams)}</p>}
      </div>

      {/* Desktop/tablet table. Mobile uses compact cards so the full team information and actions stay within the viewport. */}
      <div className="hidden overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm sm:block">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[850px]">
            <thead className="border-b border-gray-200 bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Team</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Game</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Members</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Privacy</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Created</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Captain ID</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {loading ? (
                <tr><td colSpan={6} className="px-6 py-10 text-center text-gray-500">Loading teams...</td></tr>
              ) : teams.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-10 text-center text-sm text-gray-500"><Users2 size={32} className="mx-auto mb-3 text-gray-400" />No teams found</td></tr>
              ) : teams.map((team) => (
                <tr key={team.id} className="transition hover:bg-gray-50">
                  <td className="px-6 py-4"><TeamIdentity team={team} /></td>
                  <td className="px-6 py-4 text-sm font-medium text-gray-700">{team.game}</td>
                  <td className="px-6 py-4 text-sm text-gray-600"><span className="inline-flex items-center gap-2"><Users2 size={15} />{typeof team.member_count === 'number' ? team.member_count : 0}</span></td>
                  <td className="px-6 py-4 text-sm"><PrivacyBadge isPrivate={team.is_private} /></td>
                  <td className="px-6 py-4 text-sm text-gray-600">{formatDate(team.created_at)}</td>
                  <td className="max-w-[220px] truncate px-6 py-4 text-xs text-gray-500" title={team.captain_id}>{team.captain_id}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="space-y-3 sm:hidden">
        {loading ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-7 text-center text-sm text-gray-500">Loading teams...</div>
        ) : teams.length === 0 ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-7 text-center text-sm text-gray-500"><Users2 size={30} className="mx-auto mb-2 text-gray-400" />No teams found</div>
        ) : teams.map((team) => (
          <article key={team.id} className="rounded-xl border border-gray-200 bg-white p-3 shadow-sm">
            <div className="flex min-w-0 items-start gap-3">
              <TeamLogo team={team} />
              <div className="min-w-0 flex-1">
                <h3 className="break-words text-sm font-semibold leading-5 text-gray-900">{team.name}</h3>
                <p className="mt-0.5 break-all text-[10px] text-gray-400">ID: {team.id}</p>
              </div>
              <PrivacyBadge isPrivate={team.is_private} compact />
            </div>

            <div className="mt-3 grid grid-cols-2 gap-x-3 gap-y-2 border-t border-gray-100 pt-3">
              <Info label="Game" value={team.game || '—'} />
              <Info label="Members" value={String(typeof team.member_count === 'number' ? team.member_count : 0)} />
              <Info label="Created" value={formatDate(team.created_at)} />
              <div className="min-w-0">
                <p className="text-[10px] text-gray-400">Captain ID</p>
                <p className="mt-0.5 truncate text-xs font-medium text-gray-700" title={team.captain_id}>{team.captain_id}</p>
              </div>
            </div>
          </article>
        ))}
      </div>

      <div className="mt-4 flex items-center justify-between gap-3 sm:mt-6">
        <p className="text-xs text-gray-600 sm:text-sm">Page {page} of {totalPages}</p>
        <div className="flex gap-2">
          <button type="button" onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={!hasPreviousPage || loading}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 sm:px-4 sm:py-2 sm:text-sm">Previous</button>
          <button type="button" onClick={() => setPage((current) => current + 1)} disabled={!hasNextPage || loading}
            className="rounded-lg border border-gray-300 px-3 py-1.5 text-xs font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50 sm:px-4 sm:py-2 sm:text-sm">Next</button>
        </div>
      </div>
    </Layout>
  );
}

function TeamLogo({ team }: { team: Team }) {
  if (team.logo_url) {
    return <img src={team.logo_url} alt={`${team.name} logo`} className="h-9 w-9 shrink-0 rounded-lg border border-gray-200 object-cover" onError={(event) => { event.currentTarget.style.display = 'none'; }} />;
  }
  return <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-purple-100 text-purple-700"><Users2 size={17} /></div>;
}

function TeamIdentity({ team }: { team: Team }) {
  return <div className="flex items-center gap-3"><TeamLogo team={team} /><div className="min-w-0"><p className="truncate text-sm font-semibold text-gray-900">{team.name}</p><p className="truncate text-xs text-gray-500" title={team.id}>ID: {team.id}</p></div></div>;
}

function PrivacyBadge({ isPrivate, compact = false }: { isPrivate: boolean; compact?: boolean }) {
  return isPrivate ? (
    <span className={`inline-flex shrink-0 items-center gap-1 rounded-full bg-amber-100 px-2 ${compact ? 'py-1 text-[9px]' : 'py-1 text-xs'} font-medium text-amber-800`}><Lock size={compact ? 10 : 12} />Private</span>
  ) : (
    <span className={`inline-flex shrink-0 items-center gap-1 rounded-full bg-green-100 px-2 ${compact ? 'py-1 text-[9px]' : 'py-1 text-xs'} font-medium text-green-800`}><Globe size={compact ? 10 : 12} />Public</span>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return <div className="min-w-0"><p className="text-[10px] text-gray-400">{label}</p><p className="mt-0.5 truncate text-xs font-medium text-gray-700" title={value}>{value}</p></div>;
}