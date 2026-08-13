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
  const [error , setError] = useState<string | null>(null);
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
      {/* Create Button */}
      <div className="mb-6">
        <Link
          href="/tournaments/new"
          className="inline-block px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition"
        >
          Create Tournament
        </Link>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b border-gray-200">
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
              <tr>
                <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                  Loading tournaments...
                </td>
              </tr>
            ) : tournaments.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                  No tournaments found
                </td>
              </tr>
            ) : (
              tournaments.map((tournament) => (
                <tr key={tournament.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm text-gray-900 font-medium">{tournament.name}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">{tournament.game}</td>
                  <td className="px-6 py-4 text-sm text-gray-600 capitalize">{tournament.mode}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {tournament.registered_teams}/{tournament.total_slots}
                  </td>
                  <td className="px-6 py-4 text-sm">
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusBadge(tournament.status)}`}>
                      {tournament.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <div className="flex justify-end gap-2">
                      <Link
                        href={`/tournaments/${tournament.id}`}
                        className="p-2 hover:bg-gray-100 rounded"
                      >
                        <Eye size={16} className="text-gray-600" />
                      </Link>
                      <Link
                        href={`/tournaments/${tournament.id}/edit`}
                        className="p-2 hover:bg-gray-100 rounded"
                      >
                        <Edit2 size={16} className="text-gray-600" />
                      </Link>
                      <button
                        onClick={() => handleDelete(tournament.id)}
                        className="p-2 hover:bg-red-50 rounded"
                      >
                        <Trash2 size={16} className="text-red-600" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="mt-6 flex justify-between items-center">
        <p className="text-sm text-gray-600">Page {page}</p>
        <div className="space-x-2">
          <button
            onClick={() => setPage(Math.max(1, page - 1))}
            disabled={page === 1}
            className="px-4 py-2 border border-gray-300 rounded-lg disabled:opacity-50"
          >
            Previous
          </button>
          <button
            onClick={() => setPage(page + 1)}
            className="px-4 py-2 border border-gray-300 rounded-lg"
          >
            Next
          </button>
        </div>
      </div>
    </Layout>
  );
}