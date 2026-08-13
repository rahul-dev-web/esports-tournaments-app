'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft,
  Edit2,
  Loader2,
  Trophy,
  CalendarDays,
  Users,
  Megaphone,
  ShieldCheck,
  Clock,
} from 'lucide-react';

import Layout from '../../components/Layout';
import { tournamentsAPI } from '../../lib/api';

type Tournament = {
  id: string;
  name: string;
  game: string;
  mode: string;
  tournament_type: 'solo' | 'duo' | 'squad' | 'custom';
  starts_at: string;
  entry_requirement?: string | null;
  reward?: string | null;
  status: 'draft' | 'published' | 'closed';
  total_slots: number;
  registered_teams: number;
  team_size: number;
  ads_required: number;
  policy: 'individual_ads' | 'captain_ads';
  created_at: string;
  updated_at: string;
};

function formatDate(value: string) {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString('en-IN', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

function getStatusClasses(status: Tournament['status']) {
  switch (status) {
    case 'published':
      return 'border-emerald-400/20 bg-emerald-500/10 text-emerald-300';

    case 'closed':
      return 'border-red-400/20 bg-red-500/10 text-red-300';

    case 'draft':
    default:
      return 'border-yellow-400/20 bg-yellow-500/10 text-yellow-300';
  }
}

function getPolicyLabel(policy: Tournament['policy']) {
  if (policy === 'captain_ads') {
    return 'Captain Ads';
  }

  return 'Individual Ads';
}

function getTournamentTypeLabel(
  type: Tournament['tournament_type']
) {
  switch (type) {
    case 'solo':
      return 'Solo';

    case 'duo':
      return 'Duo';

    case 'squad':
      return 'Squad';

    case 'custom':
    default:
      return 'Custom';
  }
}

export default function TournamentDetailsPage() {
  const params = useParams();
  const router = useRouter();

  const tournamentId = Array.isArray(params?.id)
    ? params.id[0]
    : params?.id;

  const [tournament, setTournament] =
    useState<Tournament | null>(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!tournamentId) {
      setError('Tournament ID is missing.');
      setLoading(false);
      return;
    }

    const loadTournament = async () => {
      try {
        setLoading(true);
        setError(null);

        const data = await tournamentsAPI.getOne(
          tournamentId
        );

        setTournament(data);
      } catch (err: any) {
        console.error(
          'Failed to load tournament:',
          err
        );

        const message =
          err?.response?.data?.detail ||
          'Failed to load tournament.';

        setError(
          typeof message === 'string'
            ? message
            : 'Failed to load tournament.'
        );
      } finally {
        setLoading(false);
      }
    };

    loadTournament();
  }, [tournamentId]);

  if (loading) {
    return (
      <Layout
        title="Tournament"
        subtitle="Tournament details"
      >
        <div className="flex min-h-[400px] items-center justify-center">
          <div className="flex items-center gap-3 text-white/60">
            <Loader2
              size={22}
              className="animate-spin"
            />
            Loading tournament...
          </div>
        </div>
      </Layout>
    );
  }

  if (error || !tournament) {
    return (
      <Layout
        title="Tournament"
        subtitle="Tournament details"
      >
        <div className="mx-auto max-w-3xl">
          <div className="mb-6">
            <Link
              href="/tournaments"
              className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white/80 transition hover:bg-white/10 hover:text-white"
            >
              <ArrowLeft size={17} />
              Back to Tournaments
            </Link>
          </div>

          <div className="rounded-[28px] border border-red-400/20 bg-red-500/10 p-6 text-red-100">
            <h2 className="text-lg font-semibold">
              Unable to load tournament
            </h2>

            <p className="mt-2 text-sm text-red-100/70">
              {error || 'Tournament not found.'}
            </p>

            <button
              type="button"
              onClick={() => router.refresh()}
              className="mt-5 rounded-xl bg-white/10 px-4 py-2 text-sm font-medium text-white transition hover:bg-white/15"
            >
              Try Again
            </button>
          </div>
        </div>
      </Layout>
    );
  }

  const availableSlots =
    tournament.total_slots -
    tournament.registered_teams;

  return (
    <Layout
      title="Tournament Details"
      subtitle="View complete tournament information"
    >
      <div className="mx-auto max-w-6xl">
        {/* Back */}
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
          <Link
            href="/tournaments"
            className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white/80 transition hover:bg-white/10 hover:text-white"
          >
            <ArrowLeft size={17} />
            Back to Tournaments
          </Link>

          <Link
            href={`/tournaments/${tournament.id}/edit`}
            className="inline-flex items-center gap-2 rounded-xl bg-gradient-to-r from-violet-600 to-cyan-500 px-5 py-2.5 text-sm font-semibold text-white shadow-lg shadow-violet-500/20 transition hover:scale-[1.01]"
          >
            <Edit2 size={17} />
            Edit Tournament
          </Link>
        </div>

        {/* Hero */}
        <section className="rounded-[30px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl md:p-8">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-start">
            <div className="flex items-start gap-4">
              <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-cyan-400 shadow-lg shadow-violet-500/20">
                <Trophy
                  size={27}
                  className="text-white"
                />
              </div>

              <div>
                <div className="flex flex-wrap items-center gap-3">
                  <h1 className="text-2xl font-bold text-white md:text-3xl">
                    {tournament.name}
                  </h1>

                  <span
                    className={`rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-wide ${getStatusClasses(
                      tournament.status
                    )}`}
                  >
                    {tournament.status}
                  </span>
                </div>

                <p className="mt-2 text-white/50">
                  {tournament.game} • {tournament.mode}
                </p>
              </div>
            </div>

            <div className="rounded-2xl border border-white/10 bg-black/10 px-4 py-3 text-sm">
              <p className="text-white/40">
                Tournament ID
              </p>

              <p className="mt-1 break-all font-mono text-xs text-white/70">
                {tournament.id}
              </p>
            </div>
          </div>
        </section>

        {/* Main stats */}
        <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-3">
          <div className="rounded-[24px] border border-white/10 bg-white/5 p-5">
            <div className="flex items-center gap-3">
              <div className="rounded-xl bg-violet-500/10 p-3">
                <Users
                  size={20}
                  className="text-violet-300"
                />
              </div>

              <div>
                <p className="text-sm text-white/50">
                  Registered Teams
                </p>

                <p className="mt-1 text-2xl font-bold text-white">
                  {tournament.registered_teams}
                  <span className="ml-1 text-base font-normal text-white/40">
                    / {tournament.total_slots}
                  </span>
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-[24px] border border-white/10 bg-white/5 p-5">
            <div className="flex items-center gap-3">
              <div className="rounded-xl bg-cyan-500/10 p-3">
                <CalendarDays
                  size={20}
                  className="text-cyan-300"
                />
              </div>

              <div>
                <p className="text-sm text-white/50">
                  Start Date
                </p>

                <p className="mt-1 text-sm font-semibold text-white">
                  {formatDate(tournament.starts_at)}
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-[24px] border border-white/10 bg-white/5 p-5">
            <div className="flex items-center gap-3">
              <div className="rounded-xl bg-emerald-500/10 p-3">
                <ShieldCheck
                  size={20}
                  className="text-emerald-300"
                />
              </div>

              <div>
                <p className="text-sm text-white/50">
                  Available Slots
                </p>

                <p className="mt-1 text-2xl font-bold text-white">
                  {Math.max(0, availableSlots)}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Details */}
        <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
          {/* Tournament configuration */}
          <section className="rounded-[28px] border border-white/10 bg-white/5 p-6">
            <div className="flex items-center gap-3">
              <Trophy
                size={20}
                className="text-cyan-300"
              />

              <h2 className="text-lg font-bold text-white">
                Tournament Configuration
              </h2>
            </div>

            <div className="mt-6 divide-y divide-white/10">
              <DetailRow
                label="Game"
                value={tournament.game}
              />

              <DetailRow
                label="Mode"
                value={tournament.mode}
              />

              <DetailRow
                label="Tournament Type"
                value={getTournamentTypeLabel(
                  tournament.tournament_type
                )}
              />

              <DetailRow
                label="Team Size"
                value={`${tournament.team_size} ${
                  tournament.team_size === 1
                    ? 'player'
                    : 'players'
                }`}
              />

              <DetailRow
                label="Total Slots"
                value={String(
                  tournament.total_slots
                )}
              />

              <DetailRow
                label="Registered Teams"
                value={String(
                  tournament.registered_teams
                )}
              />
            </div>
          </section>

          {/* Registration */}
          <section className="rounded-[28px] border border-white/10 bg-white/5 p-6">
            <div className="flex items-center gap-3">
              <Megaphone
                size={20}
                className="text-violet-300"
              />

              <h2 className="text-lg font-bold text-white">
                Registration & Ads
              </h2>
            </div>

            <div className="mt-6 divide-y divide-white/10">
              <DetailRow
                label="Ads Required"
                value={String(
                  tournament.ads_required
                )}
              />

              <DetailRow
                label="Registration Policy"
                value={getPolicyLabel(
                  tournament.policy
                )}
              />

              <DetailRow
                label="Entry Requirement"
                value={
                  tournament.entry_requirement ||
                  'No specific requirement'
                }
              />

              <DetailRow
                label="Reward"
                value={
                  tournament.reward ||
                  'No reward specified'
                }
              />

              <DetailRow
                label="Start Date & Time"
                value={formatDate(
                  tournament.starts_at
                )}
              />
            </div>
          </section>
        </div>

        {/* Metadata */}
        <section className="mt-6 rounded-[28px] border border-white/10 bg-white/5 p-6">
          <div className="flex items-center gap-3">
            <Clock
              size={20}
              className="text-white/60"
            />

            <h2 className="text-lg font-bold text-white">
              Record Information
            </h2>
          </div>

          <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
            <div>
              <p className="text-xs uppercase tracking-wide text-white/40">
                Created
              </p>

              <p className="mt-1 text-sm text-white/80">
                {formatDate(tournament.created_at)}
              </p>
            </div>

            <div>
              <p className="text-xs uppercase tracking-wide text-white/40">
                Last Updated
              </p>

              <p className="mt-1 text-sm text-white/80">
                {formatDate(tournament.updated_at)}
              </p>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  );
}

function DetailRow({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="flex flex-col gap-1 py-4 sm:flex-row sm:items-center sm:justify-between sm:gap-6">
      <span className="text-sm text-white/45">
        {label}
      </span>

      <span className="text-sm font-medium text-white/85 sm:text-right">
        {value}
      </span>
    </div>
  );
}