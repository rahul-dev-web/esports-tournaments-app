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
    if (selectedTournament) {
      fetchRegistrations(selectedTournament);
    }
  }, [selectedTournament]);

  const fetchTournaments = async () => {
    try {
      const data = await tournamentsAPI.getAll(1, 100);
      setTournaments(data);
      if (data.length > 0) {
        setSelectedTournament(data[0].id);
      }
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
      setRegistrations(registrations.filter((r) => r.id !== id));
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
      <div className="mb-6">
        <label className="block text-sm font-medium text-gray-900 mb-2">
          Filter by Tournament
        </label>
        <select
          value={selectedTournament}
          onChange={(e) => setSelectedTournament(e.target.value)}
          className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-600"
        >
          {tournaments.map((tournament) => (
            <option key={tournament.id} value={tournament.id}>
              {tournament.name}
            </option>
          ))}
        </select>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Team</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Captain</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Ads Progress</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
              <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Slot</th>
              <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {loading ? (
              <tr>
                <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                  Loading registrations...
                </td>
              </tr>
            ) : registrations.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-6 py-4 text-center text-gray-500">
                  No registrations found
                </td>
              </tr>
            ) : (
              registrations.map((registration) => (
                <tr key={registration.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm font-medium text-gray-900">{registration.team_id}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">{registration.captain_id}</td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {registration.ads_completed}/{registration.ads_required}
                  </td>
                  <td className="px-6 py-4 text-sm">
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(registration.status)}`}>
                      {registration.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {registration.slot || '-'}
                  </td>
                  <td className="px-6 py-4 text-right">
                    <div className="flex justify-end gap-2">
                      <Link
                        href={`/registrations/${registration.id}`}
                        className="p-2 hover:bg-gray-100 rounded"
                      >
                        <Eye size={16} className="text-gray-600" />
                      </Link>
                      <button
                        onClick={() => handleCancel(registration.id)}
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
    </Layout>
  );
}