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

      /*
       * Backend response:
       *
       * {
       *   total: number,
       *   skip: number,
       *   limit: number,
       *   teams: [...]
       * }
       *
       * Keep a small compatibility fallback in case the API
       * ever returns a raw array.
       */
      if (Array.isArray(data)) {
        setTeams(data);
        setTotalTeams(data.length);
        return;
      }

      const response = data as TeamsResponse;

      const teamList = Array.isArray(response?.teams)
        ? response.teams
        : [];

      setTeams(teamList);
      setTotalTeams(
        typeof response?.total === 'number'
          ? response.total
          : teamList.length
      );
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
    if (!value) {
      return '—';
    }

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
      return '—';
    }

    return date.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });
  };

  const totalPages = Math.max(1, Math.ceil(totalTeams / limit));

  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return (
    <Layout
      title="Teams"
      subtitle="Manage all registered teams"
    >
      <div className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">
            Team Management
          </h2>

          <p className="mt-1 text-sm text-gray-500">
            View teams created by players and their current membership
            details.
          </p>
        </div>

        <button
          type="button"
          onClick={handleRefresh}
          disabled={refreshing || loading}
          className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <RefreshCw
            size={16}
            className={refreshing ? 'animate-spin' : ''}
          />

          Refresh
        </button>
      </div>

      {error && (
        <div className="mb-6 flex items-center justify-between rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <span>{error}</span>

          <button
            type="button"
            onClick={handleRefresh}
            className="font-medium underline hover:no-underline"
          >
            Retry
          </button>
        </div>
      )}

      <div className="mb-4 flex items-center justify-between">
        <p className="text-sm text-gray-500">
          {totalTeams} {totalTeams === 1 ? 'team' : 'teams'} total
        </p>

        {totalTeams > 0 && (
          <p className="text-sm text-gray-500">
            Showing {(page - 1) * limit + 1}–
            {Math.min(page * limit, totalTeams)}
          </p>
        )}
      </div>

      <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[850px]">
            <thead className="border-b border-gray-200 bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Team
                </th>

                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Game
                </th>

                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Members
                </th>

                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Privacy
                </th>

                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Created
                </th>

                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                  Captain ID
                </th>
              </tr>
            </thead>

            <tbody className="divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td
                    colSpan={6}
                    className="px-6 py-10 text-center text-gray-500"
                  >
                    Loading teams...
                  </td>
                </tr>
              ) : teams.length === 0 ? (
                <tr>
                  <td
                    colSpan={6}
                    className="px-6 py-10 text-center"
                  >
                    <div className="flex flex-col items-center justify-center">
                      <Users2
                        size={32}
                        className="mb-3 text-gray-400"
                      />

                      <p className="text-sm font-medium text-gray-700">
                        No teams found
                      </p>

                      <p className="mt-1 text-sm text-gray-500">
                        Teams created by players will appear here.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                teams.map((team) => {
                  const memberCount =
                    typeof team.member_count === 'number'
                      ? team.member_count
                      : 0;

                  return (
                    <tr
                      key={team.id}
                      className="transition hover:bg-gray-50"
                    >
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          {team.logo_url ? (
                            <img
                              src={team.logo_url}
                              alt={`${team.name} logo`}
                              className="h-10 w-10 rounded-lg border border-gray-200 object-cover"
                              onError={(event) => {
                                event.currentTarget.style.display = 'none';
                              }}
                            />
                          ) : (
                            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-100 text-purple-700">
                              <Users2 size={19} />
                            </div>
                          )}

                          <div className="min-w-0">
                            <p className="truncate text-sm font-semibold text-gray-900">
                              {team.name}
                            </p>

                            <p
                              className="truncate text-xs text-gray-500"
                              title={team.id}
                            >
                              ID: {team.id}
                            </p>
                          </div>
                        </div>
                      </td>

                      <td className="px-6 py-4 text-sm font-medium text-gray-700">
                        {team.game}
                      </td>

                      <td className="px-6 py-4 text-sm text-gray-600">
                        <span className="inline-flex items-center gap-2">
                          <Users2 size={15} />
                          {memberCount}
                        </span>
                      </td>

                      <td className="px-6 py-4 text-sm">
                        {team.is_private ? (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-100 px-3 py-1 text-xs font-medium text-amber-800">
                            <Lock size={12} />
                            Private
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-green-100 px-3 py-1 text-xs font-medium text-green-800">
                            <Globe size={12} />
                            Public
                          </span>
                        )}
                      </td>

                      <td className="px-6 py-4 text-sm text-gray-600">
                        {formatDate(team.created_at)}
                      </td>

                      <td
                        className="max-w-[220px] truncate px-6 py-4 text-xs text-gray-500"
                        title={team.captain_id}
                      >
                        {team.captain_id}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Page {page} of {totalPages}
        </p>

        <div className="flex gap-2">
          <button
            type="button"
            onClick={() =>
              setPage((current) => Math.max(1, current - 1))
            }
            disabled={!hasPreviousPage || loading}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Previous
          </button>

          <button
            type="button"
            onClick={() =>
              setPage((current) => current + 1)
            }
            disabled={!hasNextPage || loading}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Next
          </button>
        </div>
      </div>
    </Layout>
  );
}