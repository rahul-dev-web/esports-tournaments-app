'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { AlertCircle } from 'lucide-react';
import { adminAPI } from '../lib/api';

interface Setting {
  key: string;
  value: string;
  description?: string;
  type: string;
}

const inputClassName =
  'w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 placeholder:text-gray-400 caret-purple-600 focus:outline-none focus:ring-2 focus:ring-purple-600 disabled:bg-gray-100 disabled:text-gray-500';

const selectClassName =
  'w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-gray-900 focus:outline-none focus:ring-2 focus:ring-purple-600';

export default function SettingsPage() {
  const [settings, setSettings] = useState<Record<string, Setting>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    fetchSettings();
  }, []);

  async function fetchSettings() {
    try {
      setLoading(true);
      const data = await adminAPI.getSettings();
      const settingsMap: Record<string, Setting> = {};

      data.forEach((s: Setting) => {
        settingsMap[s.key] = s;
      });

      setSettings(settingsMap);
    } catch (err) {
      console.error('Error fetching settings:', err);
      setError('Failed to load settings');
    } finally {
      setLoading(false);
    }
  }

  async function saveSetting(key: string, value: string, type: string) {
    try {
      setSaving(true);
      setError(null);
      await adminAPI.updateSetting(key, {
        value,
        type,
        description: settings[key]?.description,
      });

      setSettings((prev) => ({
        ...prev,
        [key]: { ...prev[key], value },
      }));

      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error('Error saving setting:', err);
      setError('Failed to save setting');
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <Layout title="Settings" subtitle="Configure application settings">
        <div className="py-8 text-center">Loading settings...</div>
      </Layout>
    );
  }

  return (
    <Layout title="Settings" subtitle="Configure application behavior">
      {error && (
        <div className="mb-6 flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800">
          <AlertCircle size={20} />
          {error}
        </div>
      )}

      {success && (
        <div className="mb-6 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800">
          ✓ Settings saved successfully
        </div>
      )}

      <div className="space-y-6">
        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-bold text-gray-900">Registration Settings</h2>

          <div className="space-y-4">
            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Ads Per Registration
              </label>
              <input
                type="number"
                min="0"
                value={settings.ads_per_registration?.value || 2}
                onChange={(e) =>
                  setSettings((prev) => ({
                    ...prev,
                    ads_per_registration: {
                      ...prev.ads_per_registration,
                      value: e.target.value,
                    } as Setting,
                  }))
                }
                className={inputClassName}
              />
              <p className="mt-1 text-xs text-gray-500">
                Number of ads each player or captain must watch
              </p>
              <button
                onClick={() =>
                  saveSetting(
                    'ads_per_registration',
                    settings.ads_per_registration?.value || '2',
                    'number',
                  )
                }
                disabled={saving}
                className="mt-2 rounded-lg bg-purple-600 px-4 py-2 text-white hover:bg-purple-700 disabled:bg-gray-400"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>

            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Registration Policy
              </label>
              <select
                value={settings.registration_policy?.value || 'individual_ads'}
                onChange={(e) =>
                  setSettings((prev) => ({
                    ...prev,
                    registration_policy: {
                      ...prev.registration_policy,
                      value: e.target.value,
                    } as Setting,
                  }))
                }
                className={selectClassName}
              >
                <option value="individual_ads">Individual Ads (each player watches)</option>
                <option value="captain_ads">Captain Ads (captain watches all)</option>
              </select>
              <p className="mt-1 text-xs text-gray-500">
                Choose default policy. Can be overridden per tournament.
              </p>
              <button
                onClick={() =>
                  saveSetting(
                    'registration_policy',
                    settings.registration_policy?.value || 'individual_ads',
                    'string',
                  )
                }
                disabled={saving}
                className="mt-2 rounded-lg bg-purple-600 px-4 py-2 text-white hover:bg-purple-700 disabled:bg-gray-400"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>

            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Maximum Team Size
              </label>
              <input
                type="number"
                min="1"
                value={settings.max_team_size?.value || 5}
                onChange={(e) =>
                  setSettings((prev) => ({
                    ...prev,
                    max_team_size: {
                      ...prev.max_team_size,
                      value: e.target.value,
                    } as Setting,
                  }))
                }
                className={inputClassName}
              />
              <p className="mt-1 text-xs text-gray-500">
                Maximum players allowed in a single team
              </p>
              <button
                onClick={() =>
                  saveSetting(
                    'max_team_size',
                    settings.max_team_size?.value || '5',
                    'number',
                  )
                }
                disabled={saving}
                className="mt-2 rounded-lg bg-purple-600 px-4 py-2 text-white hover:bg-purple-700 disabled:bg-gray-400"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="mb-4 text-lg font-bold text-gray-900">Reward Settings</h2>

          <div className="space-y-4">
            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Reward Amount
              </label>
              <input
                type="number"
                min="0"
                value={settings.reward_amount?.value || 1000}
                onChange={(e) =>
                  setSettings((prev) => ({
                    ...prev,
                    reward_amount: {
                      ...prev.reward_amount,
                      value: e.target.value,
                    } as Setting,
                  }))
                }
                className={inputClassName}
              />
              <button
                onClick={() =>
                  saveSetting(
                    'reward_amount',
                    settings.reward_amount?.value || '1000',
                    'number',
                  )
                }
                disabled={saving}
                className="mt-2 rounded-lg bg-purple-600 px-4 py-2 text-white hover:bg-purple-700 disabled:bg-gray-400"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>

            <div className="mb-4">
              <label className="mb-2 block text-sm font-medium text-gray-700">
                Currency
              </label>
              <input
                type="text"
                value={settings.reward_currency?.value || 'INR'}
                onChange={(e) =>
                  setSettings((prev) => ({
                    ...prev,
                    reward_currency: {
                      ...prev.reward_currency,
                      value: e.target.value,
                    } as Setting,
                  }))
                }
                className={inputClassName}
              />
              <button
                onClick={() =>
                  saveSetting(
                    'reward_currency',
                    settings.reward_currency?.value || 'INR',
                    'string',
                  )
                }
                disabled={saving}
                className="mt-2 rounded-lg bg-purple-600 px-4 py-2 text-white hover:bg-purple-700 disabled:bg-gray-400"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
