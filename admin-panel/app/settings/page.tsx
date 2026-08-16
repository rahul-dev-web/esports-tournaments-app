'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { AlertCircle, Info, Save, ShieldCheck } from 'lucide-react';
import { adminAPI } from '../lib/api';

interface Setting {
  key: string;
  value: string | number;
  description?: string;
  value_type: string;
}

type SettingsState = Record<string, Setting>;

const inputClassName =
  'w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 !text-slate-900 placeholder:text-slate-400 caret-violet-600 shadow-sm outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-500';

const selectClassName =
  'w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-slate-900 !text-slate-900 shadow-sm outline-none transition focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 disabled:cursor-not-allowed disabled:bg-slate-100';

const DEFAULTS = {
  ads_per_registration: '2',
  registration_policy: 'individual_ads',
  max_team_size: '5',
};

function settingValue(
  settings: SettingsState,
  key: keyof typeof DEFAULTS,
): string {
  const value = settings[key]?.value;
  return value === undefined || value === null ? DEFAULTS[key] : String(value);
}

export default function SettingsPage() {
  const [settings, setSettings] = useState<SettingsState>({});
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    void fetchSettings();
  }, []);

  async function fetchSettings() {
    try {
      setLoading(true);
      setError(null);

      const data = await adminAPI.getSettings();
      const settingsMap: SettingsState = {};

      data.forEach((setting: Setting) => {
        settingsMap[setting.key] = setting;
      });

      setSettings(settingsMap);
    } catch (err) {
      console.error('Error fetching settings:', err);
      setError('Failed to load settings.');
    } finally {
      setLoading(false);
    }
  }

  function updateLocalSetting(key: string, value: string) {
    setSettings((previous) => ({
      ...previous,
      [key]: {
        ...(previous[key] ?? {
          key,
          description: undefined,
          value_type: 'string',
        }),
        value,
      },
    }));
  }

  async function saveSetting(
    key: keyof typeof DEFAULTS,
    value: string,
    valueType: 'number' | 'string',
  ) {
    try {
      setSavingKey(key);
      setError(null);
      setSuccess(null);

      const parsedValue = valueType === 'number' ? Number(value) : value;

      if (valueType === 'number') {
        if (!Number.isInteger(parsedValue) || parsedValue < 0) {
          setError(`${key} must be a non-negative whole number.`);
          return;
        }

        if (key === 'max_team_size' && parsedValue < 1) {
          setError('Maximum team size must be at least 1.');
          return;
        }
      }

      await adminAPI.updateSetting(key, {
        value: parsedValue,
        value_type: valueType,
        description: settings[key]?.description,
      });

      setSettings((previous) => ({
        ...previous,
        [key]: {
          ...(previous[key] ?? { key }),
          value: parsedValue,
          value_type: valueType,
        },
      }));

      setSuccess(`${key.replaceAll('_', ' ')} saved successfully.`);
      window.setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error('Error saving setting:', err);
      setError(`Failed to save ${key.replaceAll('_', ' ')}.`);
    } finally {
      setSavingKey(null);
    }
  }

  const adsPerRegistration = settingValue(settings, 'ads_per_registration');
  const registrationPolicy = settingValue(settings, 'registration_policy');
  const maxTeamSize = settingValue(settings, 'max_team_size');

  if (loading) {
    return (
      <Layout title="Settings" subtitle="Configure registration and platform defaults">
        <div className="mx-auto max-w-5xl py-12 text-center text-white/70">
          Loading settings...
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Settings" subtitle="Configure registration and platform defaults">
      <div className="mx-auto max-w-5xl space-y-6">
        {error && (
          <div className="flex items-start gap-3 rounded-2xl border border-red-400/25 bg-red-500/10 p-4 text-red-100">
            <AlertCircle size={20} className="mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {success && (
          <div className="rounded-2xl border border-emerald-400/25 bg-emerald-500/10 p-4 text-emerald-100">
            ✓ {success}
          </div>
        )}

        <section className="overflow-hidden rounded-[28px] border border-white/10 bg-white/5 shadow-2xl backdrop-blur-xl">
          <div className="border-b border-white/10 p-6 sm:p-7">
            <div className="flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-violet-500/15 text-violet-300">
                <ShieldCheck size={24} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-white">Registration &amp; Ad Settings</h2>
                <p className="mt-1 max-w-3xl text-sm leading-6 text-white/55">
                  These are platform defaults for tournament registration. A tournament can override
                  its advertisement count and registration policy when it is created or edited.
                </p>
              </div>
            </div>
          </div>

          <div className="grid gap-6 p-6 sm:p-7 lg:grid-cols-2">
            <div className="rounded-2xl border border-white/10 bg-black/10 p-5">
              <label className="mb-2 block text-sm font-semibold text-white">
                Ads Per Registration
              </label>
              <input
                type="number"
                min="0"
                step="1"
                inputMode="numeric"
                value={adsPerRegistration}
                onChange={(event) => updateLocalSetting('ads_per_registration', event.target.value)}
                disabled={savingKey !== null}
                className={inputClassName}
              />
              <p className="mt-2 text-xs leading-5 text-white/50">
                Default number of rewarded ads required before a registration can be completed.
              </p>
              <button
                type="button"
                onClick={() => saveSetting('ads_per_registration', adsPerRegistration, 'number')}
                disabled={savingKey !== null}
                className="mt-4 inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-violet-500 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <Save size={16} />
                {savingKey === 'ads_per_registration' ? 'Saving...' : 'Save'}
              </button>
            </div>

            <div className="rounded-2xl border border-white/10 bg-black/10 p-5">
              <label className="mb-2 block text-sm font-semibold text-white">
                Registration Policy
              </label>
              <select
                value={registrationPolicy}
                onChange={(event) => updateLocalSetting('registration_policy', event.target.value)}
                disabled={savingKey !== null}
                className={selectClassName}
              >
                <option value="individual_ads">Individual Ads — each player watches</option>
                <option value="captain_ads">Captain Ads — captain watches all</option>
              </select>
              <p className="mt-2 text-xs leading-5 text-white/50">
                Default policy for new tournament registrations. It can be overridden per tournament.
              </p>
              <button
                type="button"
                onClick={() => saveSetting('registration_policy', registrationPolicy, 'string')}
                disabled={savingKey !== null}
                className="mt-4 inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-violet-500 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <Save size={16} />
                {savingKey === 'registration_policy' ? 'Saving...' : 'Save'}
              </button>
            </div>

            <div className="rounded-2xl border border-white/10 bg-black/10 p-5 lg:col-span-2">
              <label className="mb-2 block text-sm font-semibold text-white">
                Maximum Team Size
              </label>
              <div className="max-w-xl">
                <input
                  type="number"
                  min="1"
                  step="1"
                  inputMode="numeric"
                  value={maxTeamSize}
                  onChange={(event) => updateLocalSetting('max_team_size', event.target.value)}
                  disabled={savingKey !== null}
                  className={inputClassName}
                />
                <p className="mt-2 text-xs leading-5 text-white/50">
                  Platform-wide maximum number of players allowed in a single team.
                </p>
                <button
                  type="button"
                  onClick={() => saveSetting('max_team_size', maxTeamSize, 'number')}
                  disabled={savingKey !== null}
                  className="mt-4 inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-violet-500 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <Save size={16} />
                  {savingKey === 'max_team_size' ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </section>

        <section className="rounded-2xl border border-cyan-400/15 bg-cyan-400/5 p-5">
          <div className="flex items-start gap-3">
            <Info size={19} className="mt-0.5 shrink-0 text-cyan-300" />
            <div className="text-sm leading-6 text-white/65">
              <p className="font-semibold text-white">Where is the tournament reward configured?</p>
              <p className="mt-1">
                Prize/reward information belongs to the individual tournament, not this global
                settings page. Configure it in <strong className="text-white">Create/Edit Tournament → Reward</strong>.
                The settings page controls the rewarded-ad registration mechanism only.
              </p>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  );
}
