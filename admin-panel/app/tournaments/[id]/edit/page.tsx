'use client';

import React, {
  FormEvent,
  useEffect,
  useState,
} from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import {
  ArrowLeft,
  Loader2,
  Save,
  Trophy,
} from 'lucide-react';

import Layout from '../../../components/Layout';
import { tournamentsAPI } from '../../../lib/api';

type TournamentType =
  | 'solo'
  | 'duo'
  | 'squad'
  | 'custom';

type TournamentStatus =
  | 'draft'
  | 'published'
  | 'closed';

type RegistrationPolicy =
  | 'individual_ads'
  | 'captain_ads';

type Tournament = {
  id: string;
  name: string;
  game: string;
  mode: string;
  tournament_type: TournamentType;
  starts_at: string;
  entry_requirement?: string | null;
  reward?: string | null;
  status: TournamentStatus;
  total_slots: number;
  registered_teams: number;
  team_size: number;
  ads_required: number;
  policy: RegistrationPolicy;
  created_at: string;
  updated_at: string;
};

function toDateTimeLocal(value: string) {
  if (!value) return '';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '';
  }

  const year = date.getFullYear();
  const month = String(
    date.getMonth() + 1
  ).padStart(2, '0');

  const day = String(
    date.getDate()
  ).padStart(2, '0');

  const hours = String(
    date.getHours()
  ).padStart(2, '0');

  const minutes = String(
    date.getMinutes()
  ).padStart(2, '0');

  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

export default function EditTournamentPage() {
  const router = useRouter();
  const params = useParams();

  const tournamentId = Array.isArray(params?.id)
    ? params.id[0]
    : params?.id;

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [error, setError] = useState<string | null>(
    null
  );

  const [success, setSuccess] = useState<
    string | null
  >(null);

  const [existingTournament, setExistingTournament] =
    useState<Tournament | null>(null);

  const [form, setForm] = useState({
    name: '',
    game: '',
    mode: '',
    tournament_type: 'solo' as TournamentType,
    starts_at: '',
    entry_requirement: '',
    reward: '',
    status: 'draft' as TournamentStatus,
    total_slots: '10',
    team_size: '1',
    ads_required: '0',
    policy:
      'individual_ads' as RegistrationPolicy,
  });

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

        const data =
          await tournamentsAPI.getOne(
            tournamentId
          );

        const tournament =
          data as Tournament;

        setExistingTournament(tournament);

        setForm({
          name: tournament.name ?? '',
          game: tournament.game ?? '',
          mode: tournament.mode ?? '',
          tournament_type:
            tournament.tournament_type ??
            'custom',
          starts_at: toDateTimeLocal(
            tournament.starts_at
          ),
          entry_requirement:
            tournament.entry_requirement ?? '',
          reward: tournament.reward ?? '',
          status:
            tournament.status ?? 'draft',
          total_slots: String(
            tournament.total_slots ?? 1
          ),
          team_size: String(
            tournament.team_size ?? 1
          ),
          ads_required: String(
            tournament.ads_required ?? 0
          ),
          policy:
            tournament.policy ??
            'individual_ads',
        });
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

  const updateField = (
    field: keyof typeof form,
    value: string
  ) => {
    setForm((previous) => ({
      ...previous,
      [field]: value,
    }));
  };

  const handleTournamentTypeChange = (
    value: TournamentType
  ) => {
    let teamSize = form.team_size;

    if (value === 'solo') {
      teamSize = '1';
    } else if (value === 'duo') {
      teamSize = '2';
    } else if (value === 'squad') {
      teamSize = '4';
    }

    setForm((previous) => ({
      ...previous,
      tournament_type: value,
      team_size: teamSize,
    }));
  };

  const handleSubmit = async (
    event: FormEvent<HTMLFormElement>
  ) => {
    event.preventDefault();

    setError(null);
    setSuccess(null);

    const name = form.name.trim();
    const game = form.game.trim();
    const mode = form.mode.trim();

    if (!name) {
      setError(
        'Tournament name is required.'
      );
      return;
    }

    if (name.length < 3) {
      setError(
        'Tournament name must contain at least 3 characters.'
      );
      return;
    }

    if (!game) {
      setError('Game name is required.');
      return;
    }

    if (!mode) {
      setError(
        'Tournament mode is required.'
      );
      return;
    }

    if (!form.starts_at) {
      setError(
        'Tournament start date and time are required.'
      );
      return;
    }

    const totalSlots = Number(
      form.total_slots
    );

    const teamSize = Number(
      form.team_size
    );

    const adsRequired = Number(
      form.ads_required
    );

    if (
      !Number.isInteger(totalSlots) ||
      totalSlots <= 0
    ) {
      setError(
        'Total slots must be a positive whole number.'
      );
      return;
    }

    if (
      !Number.isInteger(teamSize) ||
      teamSize <= 0
    ) {
      setError(
        'Team size must be a positive whole number.'
      );
      return;
    }

    if (
      !Number.isInteger(adsRequired) ||
      adsRequired < 0
    ) {
      setError(
        'Ads required must be zero or a positive whole number.'
      );
      return;
    }

    if (
      existingTournament &&
      totalSlots <
        existingTournament.registered_teams
    ) {
      setError(
        `Total slots cannot be lower than the currently registered teams (${existingTournament.registered_teams}).`
      );
      return;
    }

    try {
      setSaving(true);

      const payload = {
        name,
        game,
        mode,
        tournament_type:
          form.tournament_type,
        starts_at: new Date(
          form.starts_at
        ).toISOString(),
        entry_requirement:
          form.entry_requirement.trim(),
        reward: form.reward.trim(),
        status: form.status,
        total_slots: totalSlots,

        // Preserve existing registrations.
        registered_teams:
          existingTournament?.registered_teams ??
          0,

        team_size: teamSize,
        ads_required: adsRequired,
        policy: form.policy,
      };

      await tournamentsAPI.update(
        tournamentId as string,
        payload
      );

      setSuccess(
        'Tournament updated successfully.'
      );

      setTimeout(() => {
        router.push(
          `/tournaments/${tournamentId}`
        );
        router.refresh();
      }, 700);
    } catch (err: any) {
      console.error(
        'Failed to update tournament:',
        err
      );

      const message =
        err?.response?.data?.detail ||
        err?.response?.data?.message ||
        'Failed to update tournament. Please try again.';

      setError(
        typeof message === 'string'
          ? message
          : 'Failed to update tournament. Please try again.'
      );
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <Layout
        title="Edit Tournament"
        subtitle="Update tournament configuration"
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

  if (error && !existingTournament) {
    return (
      <Layout
        title="Edit Tournament"
        subtitle="Update tournament configuration"
      >
        <div className="mx-auto max-w-3xl">
          <Link
            href="/tournaments"
            className="mb-6 inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/80 transition hover:bg-white/10"
          >
            <ArrowLeft size={17} />
            Back to Tournaments
          </Link>

          <div className="rounded-[28px] border border-red-400/20 bg-red-500/10 p-6 text-red-100">
            <h2 className="text-lg font-semibold">
              Unable to load tournament
            </h2>

            <p className="mt-2 text-sm text-red-100/70">
              {error}
            </p>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout
        title="Edit Tournament"
        subtitle="Update tournament configuration"
      >
        <div className="mx-auto max-w-5xl">
          {/* Back */}
          <div className="mb-6">
            <Link
              href={`/tournaments/${tournamentId}`}
              className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white/80 transition hover:bg-white/10 hover:text-white"
            >
              <ArrowLeft size={17} />
              Back to Tournament
            </Link>
          </div>

          {/* Header */}
          <div className="mb-6 rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <div className="flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-cyan-400">
                <Trophy
                  size={24}
                  className="text-white"
                />
              </div>

              <div>
                <h1 className="text-2xl font-bold text-white">
                  Edit Tournament
                </h1>

                <p className="mt-1 text-sm text-white/60">
                  Update the tournament information
                  and registration configuration.
                </p>
              </div>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="mb-6 rounded-2xl border border-red-400/30 bg-red-500/10 px-5 py-4 text-sm text-red-100">
              {error}
            </div>
          )}

          {/* Success */}
          {success && (
            <div className="mb-6 rounded-2xl border border-emerald-400/30 bg-emerald-500/10 px-5 py-4 text-sm text-emerald-100">
              {success}
            </div>
          )}

          <form
            onSubmit={handleSubmit}
            className="space-y-6"
          >
            {/* Basic Information */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Basic Information
              </h2>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                <div className="md:col-span-2">
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Tournament Name *
                  </label>

                  <input
                    type="text"
                    value={form.name}
                    onChange={(e) =>
                      updateField(
                        'name',
                        e.target.value
                      )
                    }
                    maxLength={120}
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Game *
                  </label>

                  <input
                    type="text"
                    value={form.game}
                    onChange={(e) =>
                      updateField(
                        'game',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Mode *
                  </label>

                  <input
                    type="text"
                    value={form.mode}
                    onChange={(e) =>
                      updateField(
                        'mode',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Tournament Type *
                  </label>

                  <select
                    value={
                      form.tournament_type
                    }
                    onChange={(e) =>
                      handleTournamentTypeChange(
                        e.target.value as TournamentType
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <option value="solo">
                      Solo
                    </option>

                    <option value="duo">
                      Duo
                    </option>

                    <option value="squad">
                      Squad
                    </option>

                    <option value="custom">
                      Custom
                    </option>
                  </select>
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Team Size *
                  </label>

                  <input
                    type="number"
                    min="1"
                    value={form.team_size}
                    onChange={(e) =>
                      updateField(
                        'team_size',
                        e.target.value
                      )
                    }
                    disabled={
                      saving ||
                      form.tournament_type !==
                        'custom'
                    }
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-50"
                  />

                  <p className="mt-2 text-xs text-white/40">
                    Solo = 1, Duo = 2, Squad = 4.
                    Custom can be changed manually.
                  </p>
                </div>
              </div>
            </section>

            {/* Schedule */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Schedule & Capacity
              </h2>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Start Date & Time *
                  </label>

                  <input
                    type="datetime-local"
                    value={form.starts_at}
                    onChange={(e) =>
                      updateField(
                        'starts_at',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Total Slots *
                  </label>

                  <input
                    type="number"
                    min={
                      existingTournament?.registered_teams ??
                      1
                    }
                    value={form.total_slots}
                    onChange={(e) =>
                      updateField(
                        'total_slots',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />

                  {existingTournament && (
                    <p className="mt-2 text-xs text-white/40">
                      Currently registered:{' '}
                      {
                        existingTournament.registered_teams
                      }
                    </p>
                  )}
                </div>
              </div>
            </section>

            {/* Entry and Reward */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Entry & Reward
              </h2>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Entry Requirement
                  </label>

                  <input
                    type="text"
                    value={
                      form.entry_requirement
                    }
                    onChange={(e) =>
                      updateField(
                        'entry_requirement',
                        e.target.value
                      )
                    }
                    maxLength={255}
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Reward
                  </label>

                  <input
                    type="text"
                    value={form.reward}
                    onChange={(e) =>
                      updateField(
                        'reward',
                        e.target.value
                      )
                    }
                    maxLength={255}
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>
              </div>
            </section>

            {/* Registration */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Registration & Advertisement
              </h2>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Ads Required
                  </label>

                  <input
                    type="number"
                    min="0"
                    value={
                      form.ads_required
                    }
                    onChange={(e) =>
                      updateField(
                        'ads_required',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Registration Policy
                  </label>

                  <select
                    value={form.policy}
                    onChange={(e) =>
                      updateField(
                        'policy',
                        e.target.value
                      )
                    }
                    disabled={saving}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <option value="individual_ads">
                      Individual Ads
                    </option>

                    <option value="captain_ads">
                      Captain Ads
                    </option>
                  </select>
                </div>
              </div>
            </section>

            {/* Status */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Tournament Status
              </h2>

              <div className="mt-6 max-w-md">
                <label className="mb-2 block text-sm font-medium text-white/80">
                  Status
                </label>

                <select
                  value={form.status}
                  onChange={(e) =>
                    updateField(
                      'status',
                      e.target.value
                    )
                  }
                  disabled={saving}
                  className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <option value="draft">
                    Draft
                  </option>

                  <option value="published">
                    Published
                  </option>

                  <option value="closed">
                    Closed
                  </option>
                </select>
              </div>
            </section>

            {/* Actions */}
            <div className="flex flex-col-reverse gap-3 pb-8 sm:flex-row sm:justify-end">
              <Link
                href={`/tournaments/${tournamentId}`}
                className="inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 px-6 py-3 text-sm font-semibold text-white/80 transition hover:bg-white/10 hover:text-white"
              >
                Cancel
              </Link>

              <button
                type="submit"
                disabled={saving}
                className="inline-flex items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-violet-600 to-cyan-500 px-7 py-3 text-sm font-semibold text-white shadow-lg shadow-violet-500/20 transition hover:scale-[1.01] disabled:cursor-not-allowed disabled:opacity-60"
              >
                {saving ? (
                  <>
                    <Loader2
                      size={18}
                      className="animate-spin"
                    />
                    Saving...
                  </>
                ) : (
                  <>
                    <Save size={18} />
                    Save Changes
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </Layout>
    </div>
  );
}