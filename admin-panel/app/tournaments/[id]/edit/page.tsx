'use client';

import React, { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { ArrowLeft, Gamepad2, Loader2, Save } from 'lucide-react';
import Layout from '../../../components/Layout';
import { tournamentsAPI } from '../../../lib/api';

type TournamentType = 'solo' | 'duo' | 'squad' | 'custom';
type TournamentStatus = 'draft' | 'published' | 'closed';
type RegistrationPolicy = 'individual_ads' | 'captain_ads';
type GameMode = 'Battle Royale' | 'CS';

type Tournament = {
  id: string;
  name: string;
  game: string;
  mode: GameMode;
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
};

const toLocal = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

export default function EditTournamentPage() {
  const router = useRouter();
  const params = useParams();
  const tournamentId = Array.isArray(params?.id) ? params.id[0] : params?.id;
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [existing, setExisting] = useState<Tournament | null>(null);
  const [form, setForm] = useState({ name: '', mode: 'Battle Royale' as GameMode, tournament_type: 'solo' as TournamentType, starts_at: '', entry_requirement: '', reward: '', status: 'draft' as TournamentStatus, total_slots: '10', team_size: '1', ads_required: '0', policy: 'individual_ads' as RegistrationPolicy });

  useEffect(() => {
    if (!tournamentId) return;
    tournamentsAPI.getOne(tournamentId)
      .then((data) => {
        const t = data as Tournament;
        setExisting(t);
        setForm({
          name: t.name ?? '',
          mode: t.mode === 'CS' ? 'CS' : 'Battle Royale',
          tournament_type: t.tournament_type ?? 'custom',
          starts_at: toLocal(t.starts_at),
          entry_requirement: t.entry_requirement ?? '',
          reward: t.reward ?? '',
          status: t.status ?? 'draft',
          total_slots: String(t.total_slots ?? 1),
          team_size: String(t.team_size ?? 1),
          ads_required: String(t.ads_required ?? 0),
          policy: t.policy ?? 'individual_ads',
        });
      })
      .catch((err: any) => setError(err?.response?.data?.detail || 'Failed to load tournament.'))
      .finally(() => setLoading(false));
  }, [tournamentId]);

  const updateField = (field: keyof typeof form, value: string) => setForm((p) => ({ ...p, [field]: value }));
  const changeType = (value: TournamentType) => {
    const teamSize = value === 'solo' ? '1' : value === 'duo' ? '2' : value === 'squad' ? '4' : '5';
    setForm((p) => ({ ...p, tournament_type: value, team_size: teamSize }));
  };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setSuccess(null);
    const name = form.name.trim();
    const totalSlots = Number(form.total_slots);
    const teamSize = Number(form.team_size);
    const adsRequired = Number(form.ads_required);
    if (name.length < 3) return setError('Tournament name must contain at least 3 characters.');
    if (!form.starts_at) return setError('Tournament start date and time are required.');
    if (!Number.isInteger(totalSlots) || totalSlots <= 0) return setError('Total slots must be a positive whole number.');
    if (existing && totalSlots < existing.registered_teams) return setError(`Total slots cannot be lower than ${existing.registered_teams} registered teams.`);
    if (!Number.isInteger(teamSize) || teamSize < 1 || teamSize > 5) return setError('Custom tournaments can have at most 5 players.');
    if (!Number.isInteger(adsRequired) || adsRequired < 0) return setError('Ads required must be zero or a positive whole number.');

    try {
      setSaving(true);
      await tournamentsAPI.update(tournamentId as string, {
        name,
        game: 'Free Fire',
        mode: form.mode,
        tournament_type: form.tournament_type,
        starts_at: new Date(form.starts_at).toISOString(),
        entry_requirement: form.entry_requirement.trim(),
        reward: form.reward.trim(),
        status: form.status,
        total_slots: totalSlots,
        registered_teams: existing?.registered_teams ?? 0,
        team_size: teamSize,
        ads_required: adsRequired,
        policy: form.policy,
      });
      setSuccess('Tournament updated successfully.');
      setTimeout(() => { router.push(`/tournaments/${tournamentId}`); router.refresh(); }, 700);
    } catch (err: any) {
      setError(err?.response?.data?.detail || err?.response?.data?.message || 'Failed to update tournament.');
    } finally {
      setSaving(false);
    }
  };

  const input = 'w-full rounded-2xl border border-white/10 bg-[#0d152b] px-4 py-3 text-white outline-none focus:border-cyan-400 disabled:opacity-60';
  const select = input;

  if (loading) return <Layout title="Edit Tournament" subtitle="Update tournament configuration"><div className="flex min-h-[400px] items-center justify-center text-white/60"><Loader2 className="mr-2 animate-spin" size={22} />Loading tournament...</div></Layout>;
  if (!existing) return <Layout title="Edit Tournament" subtitle="Update tournament configuration"><div className="rounded-2xl border border-red-400/20 bg-red-500/10 p-5 text-red-100">{error || 'Tournament not found.'}</div></Layout>;

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.18),_transparent_30%),linear-gradient(180deg,#08101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Layout title="Edit Tournament" subtitle="Free Fire only • Battle Royale / CS">
        <div className="mx-auto max-w-5xl">
          <Link href={`/tournaments/${tournamentId}`} className="mb-6 inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm text-white/80"><ArrowLeft size={17} />Back to Tournament</Link>
          {error && <div className="mb-5 rounded-2xl border border-red-400/30 bg-red-500/10 px-5 py-4 text-sm text-red-100">{error}</div>}
          {success && <div className="mb-5 rounded-2xl border border-emerald-400/30 bg-emerald-500/10 px-5 py-4 text-sm text-emerald-100">{success}</div>}
          <form onSubmit={submit} className="space-y-5">
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur-xl">
              <h2 className="text-lg font-bold">Basic Information</h2>
              <div className="mt-5 grid grid-cols-1 gap-5 md:grid-cols-2">
                <div className="md:col-span-2"><label className="mb-2 block text-sm text-white/80">Tournament Name *</label><input value={form.name} onChange={(e) => updateField('name', e.target.value)} maxLength={120} disabled={saving} className={input} /></div>
                <div><label className="mb-2 block text-sm text-white/80">Game</label><div className="flex items-center gap-3 rounded-2xl border border-cyan-400/20 bg-cyan-400/5 px-4 py-3"><Gamepad2 size={18} className="text-cyan-300" /><span className="font-semibold">Free Fire</span><span className="ml-auto text-xs text-white/40">Fixed</span></div></div>
                <div><label className="mb-2 block text-sm text-white/80">Game Mode *</label><select value={form.mode} onChange={(e) => updateField('mode', e.target.value)} disabled={saving} className={select}><option value="Battle Royale">Battle Royale</option><option value="CS">CS</option></select></div>
                <div><label className="mb-2 block text-sm text-white/80">Tournament Type *</label><select value={form.tournament_type} onChange={(e) => changeType(e.target.value as TournamentType)} disabled={saving} className={select}><option value="solo">Solo</option><option value="duo">Duo</option><option value="squad">Squad</option><option value="custom">Custom</option></select></div>
                <div><label className="mb-2 block text-sm text-white/80">Players per Registration</label><input type="number" min="1" max="5" value={form.team_size} onChange={(e) => updateField('team_size', e.target.value)} disabled={saving || form.tournament_type !== 'custom'} className={input} /><p className="mt-2 text-xs text-white/40">Solo 1 • Duo 2 • Squad 4 • Custom max 5</p></div>
              </div>
            </section>
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur-xl"><h2 className="text-lg font-bold">Schedule & Capacity</h2><div className="mt-5 grid grid-cols-1 gap-5 md:grid-cols-2"><div><label className="mb-2 block text-sm text-white/80">Start Date & Time *</label><input type="datetime-local" value={form.starts_at} onChange={(e) => updateField('starts_at', e.target.value)} disabled={saving} className={input} /></div><div><label className="mb-2 block text-sm text-white/80">Total Team Slots *</label><input type="number" min={existing.registered_teams} value={form.total_slots} onChange={(e) => updateField('total_slots', e.target.value)} disabled={saving} className={input} /></div></div></section>
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur-xl"><h2 className="text-lg font-bold">Entry & Reward</h2><div className="mt-5 grid grid-cols-1 gap-5 md:grid-cols-2"><div><label className="mb-2 block text-sm text-white/80">Entry Requirement</label><input value={form.entry_requirement} onChange={(e) => updateField('entry_requirement', e.target.value)} maxLength={255} disabled={saving} className={input} /></div><div><label className="mb-2 block text-sm text-white/80">Reward</label><input value={form.reward} onChange={(e) => updateField('reward', e.target.value)} maxLength={255} disabled={saving} className={input} /></div></div></section>
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur-xl"><h2 className="text-lg font-bold">Registration</h2><div className="mt-5 grid grid-cols-1 gap-5 md:grid-cols-2"><div><label className="mb-2 block text-sm text-white/80">Ads Required</label><input type="number" min="0" value={form.ads_required} onChange={(e) => updateField('ads_required', e.target.value)} disabled={saving} className={input} /></div><div><label className="mb-2 block text-sm text-white/80">Registration Policy</label><select value={form.policy} onChange={(e) => updateField('policy', e.target.value)} disabled={saving} className={select}><option value="individual_ads">Individual Ads</option><option value="captain_ads">Captain Ads</option></select></div></div></section>
            <section className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur-xl"><h2 className="text-lg font-bold">Status</h2><div className="mt-5 max-w-md"><select value={form.status} onChange={(e) => updateField('status', e.target.value)} disabled={saving} className={select}><option value="draft">Draft</option><option value="published">Published</option><option value="closed">Closed</option></select></div></section>
            <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><Link href={`/tournaments/${tournamentId}`} className="inline-flex items-center justify-center rounded-2xl border border-white/10 bg-white/5 px-6 py-3 font-semibold text-white/80">Cancel</Link><button type="submit" disabled={saving} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-violet-500 to-cyan-400 px-7 py-3 font-semibold disabled:opacity-60">{saving ? <><Loader2 size={18} className="animate-spin" />Saving...</> : <><Save size={18} />Save Changes</>}</button></div>
          </form>
        </div>
      </Layout>
    </div>
  );
}
