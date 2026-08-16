'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { Tournament } from '../lib/types';
import { tournamentsAPI } from '../lib/api';
import Link from 'next/link';
import { Edit2, Trash2, Eye } from 'lucide-react';

export default function TournamentsPage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);

  useEffect(() => {
    fetchTournaments();
  }, [page]);

  const fetchTournaments = async () => {
    try {
      setLoading(true);
      const data = await tournamentsAPI.getAll(page, 10);
      setTournaments(data);
    } catch (err) {
      console.error('Error fetching tournaments:', err);
      setError('Failed to load tournaments');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this tournament?')) return;
    try {
      await tournamentsAPI.delete(id);
      setTournaments(tournaments.filter((t) => t.id !== id));
    } catch (err) {
      alert('Failed to delete tournament');
    }
  };

  const getStatusBadge = (status: string) => {
    const colors: { [key: string]: string } = {
      draft: 'bg-gray-100 text-gray-800',
      published: 'bg-green-100 text-green-800',
      closed: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <Layout title="Tournaments" subtitle="Manage all tournaments">
      <div className="mb-4 sm:mb-6">
        <Link
          href="/tournaments/new"
          className="inline-block rounded-lg bg-purple-600 px-5 py-2 text-sm font-medium text-white transition hover:bg-purple-700 sm:px-6 sm:py-2"
        >
          Create Tournament
        </Link>
      </div>

      {error && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 sm:mb-6">
          {error}
        </div>
      )}

      {/* Desktop/tablet: full table. Mobile: compact card layout so actions never leave the viewport. */}
      <div className="hidden overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm sm:block">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px]">
            <thead className="border-b border-gray-200 bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Name</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Game</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Mode</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Slots</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
                <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {loading ? (
                <tr><td colSpan={6} className="px-6 py-4 text-center text-gray-500">Loading tournaments...</td></tr>
              ) : tournaments.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-4 text-center text-gray-500">No tournaments found</td></tr>
              ) : (
                tournaments.map((tournament) => (
                  <tr key={tournament.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">{tournament.name}</td>
                    <td className="px-6 py-4 text-sm text-gray-600">{tournament.game}</td>
                    <td className="px-6 py-4 text-sm capitalize text-gray-600">{tournament.mode}</td>
                    <td className="px-6 py-4 text-sm text-gray-600">{tournament.registered_teams}/{tournament.total_slots}</td>
                    <td className="px-6 py-4 text-sm"><span className={`rounded-full px-3 py-1 text-xs font-medium ${getStatusBadge(tournament.status)}`}>{tournament.status}</span></td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex justify-end gap-2">
                        <Link href={`/tournaments/${tournament.id}`} className="rounded p-2 hover:bg-gray-100" aria-label="View tournament"><Eye size={16} className="text-gray-600" /></Link>
                        <Link href={`/tournaments/${tournament.id}/edit`} className="rounded p-2 hover:bg-gray-100" aria-label="Edit tournament"><Edit2 size={16} className="text-gray-600" /></Link>
                        <button onClick={() => handleDelete(tournament.id)} className="rounded p-2 hover:bg-red-50" aria-label="Delete tournament"><Trash2 size={16} className="text-red-600" /></button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="space-y-3 sm:hidden">
        {loading ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-center text-sm text-gray-500">Loading tournaments...</div>
        ) : tournaments.length === 0 ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-center text-sm text-gray-500">No tournaments found</div>
        ) : (
          tournaments.map((tournament) => (
            <article key={tournament.id} className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <h3 className="min-w-0 flex-1 break-words text-sm font-semibold leading-5 text-gray-900">{tournament.name}</h3>
                <span className={`shrink-0 rounded-full px-2 py-1 text-[10px] font-medium ${getStatusBadge(tournament.status)}`}>{tournament.status}</span>
              </div>

              <div className="mt-3 grid grid-cols-3 gap-2 text-xs">
                <div className="min-w-0"><p className="text-gray-400">Game</p><p className="mt-0.5 truncate font-medium text-gray-700">{tournament.game}</p></div>
                <div className="min-w-0"><p className="text-gray-400">Mode</p><p className="mt-0.5 truncate font-medium capitalize text-gray-700">{tournament.mode}</p></div>
                <div><p className="text-gray-400">Slots</p><p className="mt-0.5 font-medium text-gray-700">{tournament.registered_teams}/{tournament.total_slots}</p></div>
              </div>

              <div className="mt-3 flex items-center justify-end gap-2 border-t border-gray-100 pt-3">
                <Link href={`/tournaments/${tournament.id}`} className="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50" aria-label="View tournament"><Eye size={14} />View</Link>
                <Link href={`/tournaments/${tournament.id}/edit`} className="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50" aria-label="Edit tournament"><Edit2 size={14} />Edit</Link>
                <button onClick={() => handleDelete(tournament.id)} className="inline-flex items-center gap-1.5 rounded-lg border border-red-100 px-3 py-2 text-xs font-medium text-red-600 hover:bg-red-50" aria-label="Delete tournament"><Trash2 size={14} />Delete</button>
              </div>
            </article>
          ))
        )}
      </div>

      <div className="mt-4 flex items-center justify-between sm:mt-6">
        <p className="text-xs text-gray-600 sm:text-sm">Page {page}</p>
        <div className="flex gap-2">
          <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1} className="rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:opacity-50 sm:px-4">Previous</button>
          <button onClick={() => setPage(page + 1)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm">Next</button>
        </div>
      </div>
    </Layout>
  );
}