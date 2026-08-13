'use client';

import React, { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft, Trophy, Loader2 } from 'lucide-react';

import Layout from '../../components/Layout';
import { tournamentsAPI } from '../../lib/api';

type TournamentType = 'solo' | 'duo' | 'squad' | 'custom';
type TournamentStatus = 'draft' | 'published' | 'closed';
type RegistrationPolicy = 'individual_ads' | 'captain_ads';

export default function NewTournamentPage() {
  const router = useRouter();

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

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
    policy: 'individual_ads' as RegistrationPolicy,
  });

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
      setError('Tournament name is required.');
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
      setError('Tournament mode is required.');
      return;
    }

    if (!form.starts_at) {
      setError('Tournament start date and time are required.');
      return;
    }

    const totalSlots = Number(form.total_slots);
    const teamSize = Number(form.team_size);
    const adsRequired = Number(form.ads_required);

    if (!Number.isInteger(totalSlots) || totalSlots <= 0) {
      setError('Total slots must be a positive whole number.');
      return;
    }

    if (!Number.isInteger(teamSize) || teamSize <= 0) {
      setError('Team size must be a positive whole number.');
      return;
    }

    if (!Number.isInteger(adsRequired) || adsRequired < 0) {
      setError(
        'Ads required must be zero or a positive whole number.'
      );
      return;
    }

    try {
      setLoading(true);

      const payload = {
        name,
        game,
        mode,
        tournament_type: form.tournament_type,
        starts_at: new Date(form.starts_at).toISOString(),
        entry_requirement: form.entry_requirement.trim(),
        reward: form.reward.trim(),
        status: form.status,
        total_slots: totalSlots,
        registered_teams: 0,
        team_size: teamSize,
        ads_required: adsRequired,
        policy: form.policy,
      };

      await tournamentsAPI.create(payload);

      setSuccess('Tournament created successfully.');

      setTimeout(() => {
        router.push('/tournaments');
        router.refresh();
      }, 700);
    } catch (err: any) {
      console.error(
        'Failed to create tournament:',
        err
      );

      const message =
        err?.response?.data?.detail ||
        err?.response?.data?.message ||
        'Failed to create tournament. Please try again.';

      setError(
        typeof message === 'string'
          ? message
          : 'Failed to create tournament. Please try again.'
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout
        title="Create Tournament"
        subtitle="Create and configure a new esports tournament"
      >
        <div className="mx-auto max-w-5xl">
          {/* Back button */}
          <div className="mb-6">
            <Link
              href="/tournaments"
              className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-white/80 transition hover:bg-white/10 hover:text-white"
            >
              <ArrowLeft size={17} />
              Back to Tournaments
            </Link>
          </div>

          {/* Header */}
          <div className="mb-6 rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
            <div className="flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-cyan-400">
                <Trophy size={24} className="text-white" />
              </div>

              <div>
                <h1 className="text-2xl font-bold text-white">
                  Create Tournament
                </h1>

                <p className="mt-1 text-sm text-white/60">
                  Configure the tournament details, slots,
                  advertisements and registration policy.
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

          {/* Form */}
          <form
            onSubmit={handleSubmit}
            className="space-y-6"
          >
            {/* Basic Information */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Basic Information
              </h2>

              <p className="mt-1 text-sm text-white/50">
                Basic information visible to tournament
                participants.
              </p>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                {/* Name */}
                <div className="md:col-span-2">
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Tournament Name *
                  </label>

                  <input
                    type="text"
                    value={form.name}
                    onChange={(e) =>
                      updateField('name', e.target.value)
                    }
                    placeholder="e.g. ArenaHub Summer Championship"
                    maxLength={120}
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                {/* Game */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Game *
                  </label>

                  <input
                    type="text"
                    value={form.game}
                    onChange={(e) =>
                      updateField('game', e.target.value)
                    }
                    placeholder="e.g. Free Fire"
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                {/* Mode */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Mode *
                  </label>

                  <input
                    type="text"
                    value={form.mode}
                    onChange={(e) =>
                      updateField('mode', e.target.value)
                    }
                    placeholder="e.g. Battle Royale"
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                {/* Tournament Type */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Tournament Type *
                  </label>

                  <select
                    value={form.tournament_type}
                    onChange={(e) =>
                      handleTournamentTypeChange(
                        e.target.value as TournamentType
                      )
                    }
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <option value="solo">Solo</option>
                    <option value="duo">Duo</option>
                    <option value="squad">Squad</option>
                    <option value="custom">Custom</option>
                  </select>
                </div>

                {/* Team Size */}
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
                      loading ||
                      form.tournament_type !== 'custom'
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

            {/* Schedule & Capacity */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Schedule & Capacity
              </h2>

              <p className="mt-1 text-sm text-white/50">
                Configure when the tournament starts and how
                many slots are available.
              </p>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                {/* Start */}
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
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                {/* Slots */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Total Slots *
                  </label>

                  <input
                    type="number"
                    min="1"
                    value={form.total_slots}
                    onChange={(e) =>
                      updateField(
                        'total_slots',
                        e.target.value
                      )
                    }
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>
              </div>
            </section>

            {/* Entry & Reward */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Entry & Reward
              </h2>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                {/* Entry Requirement */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Entry Requirement
                  </label>

                  <input
                    type="text"
                    value={form.entry_requirement}
                    onChange={(e) =>
                      updateField(
                        'entry_requirement',
                        e.target.value
                      )
                    }
                    placeholder="e.g. Level 10+"
                    maxLength={255}
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none placeholder:text-white/30 focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>

                {/* Reward */}
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
                    placeholder="e.g. ₹5,000"
                    maxLength={255}
                    disabled={loading}
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

              <p className="mt-1 text-sm text-white/50">
                Configure advertisement requirements for
                tournament registration.
              </p>

              <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
                {/* Ads Required */}
                <div>
                  <label className="mb-2 block text-sm font-medium text-white/80">
                    Ads Required
                  </label>

                  <input
                    type="number"
                    min="0"
                    value={form.ads_required}
                    onChange={(e) =>
                      updateField(
                        'ads_required',
                        e.target.value
                      )
                    }
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  />

                  <p className="mt-2 text-xs text-white/40">
                    Set 0 if no advertisement is required.
                  </p>
                </div>

                {/* Policy */}
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
                    disabled={loading}
                    className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <option value="individual_ads">
                      Individual Ads
                    </option>

                    <option value="captain_ads">
                      Captain Ads
                    </option>
                  </select>

                  <p className="mt-2 text-xs text-white/40">
                    Individual Ads = each participant completes
                    the required ads. Captain Ads = captain handles
                    the advertisement requirement.
                  </p>
                </div>
              </div>
            </section>

            {/* Status */}
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 shadow-2xl backdrop-blur-xl">
              <h2 className="text-lg font-bold text-white">
                Tournament Status
              </h2>

              <div className="mt-6">
                <label className="mb-2 block text-sm font-medium text-white/80">
                  Initial Status
                </label>

                <select
                  value={form.status}
                  onChange={(e) =>
                    updateField(
                      'status',
                      e.target.value
                    )
                  }
                  disabled={loading}
                  className="w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:cursor-not-allowed disabled:opacity-60 md:max-w-md"
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

                <p className="mt-2 text-xs text-white/40">
                  Draft tournaments remain unpublished. Published
                  tournaments can be shown to players.
                </p>
              </div>
            </section>

            {/* Actions */}
            <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <Link
                href="/tournaments"
                className="inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 px-6 py-3 font-semibold text-white/80 transition hover:bg-white/10 hover:text-white"
              >
                Cancel
              </Link>

              <button
                type="submit"
                disabled={loading}
                className="inline-flex items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-violet-500 to-cyan-400 px-7 py-3 font-semibold text-white shadow-lg transition hover:opacity-95 disabled:cursor-not-allowed disabled:opacity-60"
              >
                {loading ? (
                  <>
                    <Loader2
                      size={18}
                      className="animate-spin"
                    />
                    Creating...
                  </>
                ) : (
                  <>
                    <Trophy size={18} />
                    Create Tournament
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