'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { Registration, Tournament } from '../lib/types';
import { tournamentsAPI, registrationsAPI } from '../lib/api';
import { Eye, Trash2 } from 'lucide-react';
import Link from 'next/link';

export default function RegistrationsPage() {
  const [registrations, setRegistrations] = useState<Registration[]>([]);
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTournament, setSelectedTournament] = useState<string>('');

  useEffect(() => {
    fetchTournaments();
  }, []);

  useEffect(() => {
    if (selectedTournament) fetchRegistrations(selectedTournament);
  }, [selectedTournament]);

  const fetchTournaments = async () => {
    try {
      const data = await tournamentsAPI.getAll(1, 100);
      setTournaments(data);
      if (data.length > 0) setSelectedTournament(data[0].id);
    } catch (err) {
      console.error('Error fetching tournaments:', err);
    }
  };

  const fetchRegistrations = async (tournamentId: string) => {
    try {
      setLoading(true);
      const data = await registrationsAPI.getTournamentRegistrations(tournamentId);
      setRegistrations(data);
    } catch (err) {
      console.error('Error fetching registrations:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = async (id: string) => {
    if (!confirm('Cancel this registration?')) return;
    try {
      await registrationsAPI.cancel(id);
      setRegistrations((current) => current.filter((r) => r.id !== id));
    } catch (err) {
      alert('Failed to cancel registration');
    }
  };

  const getStatusColor = (status: string) => {
    const colors: { [key: string]: string } = {
      pending: 'bg-yellow-100 text-yellow-800',
      ad_verification: 'bg-blue-100 text-blue-800',
      registered: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <Layout title="Registrations" subtitle="Manage tournament registrations">
      {/* Filter */}
      <div className="mb-4">
        <label className="block text-sm font-medium text-gray-900 mb-2">
          Filter by Tournament
        </label>
        <select
          value={selectedTournament}
          onChange={(e) => setSelectedTournament(e.target.value)}
          className="w-full sm:w-auto max-w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600 text-sm"
        >
          {tournaments.map((tournament) => (
            <option key={tournament.id} value={tournament.id}>{tournament.name}</option>
          ))}
        </select>
      </div>

      {/* Mobile cards */}
      <div className="md:hidden space-y-3">
        {loading ? (
          <div className="bg-white rounded-lg border border-gray-200 p-4 text-center text-sm text-gray-500">
            Loading registrations...
          </div>
        ) : registrations.length === 0 ? (
          <div className="bg-white rounded-lg border border-gray-200 p-4 text-center text-sm text-gray-500">
            No registrations found
          </div>
        ) : (
          registrations.map((registration) => (
            <div key={registration.id} className="bg-white rounded-lg border border-gray-200 shadow-sm p-3 min-w-0">
              <div className="flex items-start justify-between gap-3 min-w-0">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-gray-900 truncate">Team: {registration.team_id}</p>
                  <p className="text-xs text-gray-500 truncate mt-1">Captain: {registration.captain_id}</p>
                </div>
                <span className={`shrink-0 px-2 py-1 rounded text-[11px] font-medium ${getStatusColor(registration.status)}`}>
                  {registration.status.replace('_', ' ')}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-2 mt-3 text-xs">
                <div className="rounded-md bg-gray-50 px-2 py-2 min-w-0">
                  <span className="block text-gray-500">Ads</span>
                  <span className="font-medium text-gray-900">{registration.ads_completed}/{registration.ads_required}</span>
                </div>
                <div className="rounded-md bg-gray-50 px-2 py-2 min-w-0">
                  <span className="block text-gray-500">Slot</span>
                  <span className="font-medium text-gray-900 truncate block">{registration.slot || '-'}</span>
                </div>
              </div>

              <div className="flex justify-end gap-2 mt-3 pt-2 border-t border-gray-100">
                <Link
                  href={`/registrations/${registration.id}`}
                  aria-label="View registration"
                  className="inline-flex items-center justify-center p-2 hover:bg-gray-100 rounded"
                >
                  <Eye size={16} className="text-gray-600" />
                </Link>
                <button
                  onClick={() => handleCancel(registration.id)}
                  aria-label="Cancel registration"
                  className="inline-flex items-center justify-center p-2 hover:bg-red-50 rounded"
                >
                  <Trash2 size={16} className="text-red-600" />
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Desktop/tablet table */}
      <div className="hidden md:block bg-white rounded-lg shadow-sm border border-gray-200 overflow-x-auto">
        <table className="w-full min-w-[760px]">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-4 lg:px-6 py-3 text-left text-sm font-semibold text-gray-900">Team</th>
              <th className="px-4 lg:px-6 py-3 text-left text-sm font-semibold text-gray-900">Captain</th>
              <th className="px-4 lg:px-6 py-3 text-left text-sm font-semibold text-gray-900">Ads Progress</th>
              <th className="px-4 lg:px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
              <th className="px-4 lg:px-6 py-3 text-left text-sm font-semibold text-gray-900">Slot</th>
              <th className="px-4 lg:px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {loading ? (
              <tr><td colSpan={6} className="px-6 py-4 text-center text-gray-500">Loading registrations...</td></tr>
            ) : registrations.length === 0 ? (
              <tr><td colSpan={6} className="px-6 py-4 text-center text-gray-500">No registrations found</td></tr>
            ) : (
              registrations.map((registration) => (
                <tr key={registration.id} className="hover:bg-gray-50">
                  <td className="px-4 lg:px-6 py-4 text-sm font-medium text-gray-900 max-w-[180px] truncate">{registration.team_id}</td>
                  <td className="px-4 lg:px-6 py-4 text-sm text-gray-600 max-w-[180px] truncate">{registration.captain_id}</td>
                  <td className="px-4 lg:px-6 py-4 text-sm text-gray-600">{registration.ads_completed}/{registration.ads_required}</td>
                  <td className="px-4 lg:px-6 py-4 text-sm">
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(registration.status)}`}>
                      {registration.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 lg:px-6 py-4 text-sm text-gray-600">{registration.slot || '-'}</td>
                  <td className="px-4 lg:px-6 py-4 text-right">
                    <div className="flex justify-end gap-2">
                      <Link href={`/registrations/${registration.id}`} className="p-2 hover:bg-gray-100 rounded" aria-label="View registration">
                        <Eye size={16} className="text-gray-600" />
                      </Link>
                      <button onClick={() => handleCancel(registration.id)} className="p-2 hover:bg-red-50 rounded" aria-label="Cancel registration">
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
    </Layout>
  );
}
