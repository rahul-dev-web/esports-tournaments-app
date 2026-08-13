'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft,
  Edit,
  User as UserIcon,
  Mail,
  MapPin,
  Gamepad2,
  Calendar,
  Shield,
  CheckCircle,
  XCircle,
  Globe,
  AtSign,
  Hash,
  Loader2,
  AlertCircle,
} from 'lucide-react';

import { usersAPI } from '../../lib/api';

interface UserDetails {
  id: string;
  email: string;
  name: string;
  username: string;
  bio: string;
  country: string;
  state: string;
  city: string;
  photo_url?: string | null;
  social_links?: Record<string, string> | null;
  preferred_game: string;
  in_game_uid?: string | null;
  role: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

function formatDate(value?: string | null) {
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

function displayValue(value?: string | null) {
  if (!value || !value.trim()) {
    return 'Not provided';
  }

  return value;
}

export default function UserDetailsPage() {
  const params = useParams();
  const router = useRouter();

  const userId = Array.isArray(params?.id)
    ? params.id[0]
    : params?.id;

  const [user, setUser] = useState<UserDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!userId || typeof userId !== 'string') {
      setError('Invalid user ID.');
      setLoading(false);
      return;
    }

    let cancelled = false;

    async function loadUser() {
      const safeUserId = userId;

      if (!safeUserId || typeof safeUserId !== 'string') {
        setError('Invalid user ID.');
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const data = await usersAPI.getOne(safeUserId);

        if (!cancelled) {
          setUser(data as UserDetails);
        }
      } catch (err: any) {
        if (cancelled) return;

        const status = err?.response?.status;

        if (status === 404) {
          setError('User not found.');
        } else if (status === 401) {
          setError('Your admin session has expired. Please log in again.');
        } else {
          setError(
            err?.response?.data?.detail ||
              err?.response?.data?.message ||
              'Failed to load user details.'
          );
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    loadUser();

    return () => {
      cancelled = true;
    };
  }, [userId]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="mx-auto max-w-6xl">
          <div className="flex min-h-[60vh] items-center justify-center">
            <div className="flex flex-col items-center gap-3 text-gray-600">
              <Loader2 className="h-8 w-8 animate-spin" />
              <p className="text-sm">Loading user details...</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !user) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="mx-auto max-w-6xl">
          <Link
            href="/users"
            className="mb-6 inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Users
          </Link>

          <div className="rounded-xl border border-red-200 bg-white p-8 shadow-sm">
            <div className="flex items-start gap-4">
              <div className="rounded-full bg-red-100 p-3">
                <AlertCircle className="h-6 w-6 text-red-600" />
              </div>

              <div>
                <h1 className="text-lg font-semibold text-gray-900">
                  Unable to load user
                </h1>

                <p className="mt-1 text-sm text-gray-600">
                  {error || 'User details could not be loaded.'}
                </p>

                <div className="mt-5 flex gap-3">
                  <button
                    type="button"
                    onClick={() => router.back()}
                    className="rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
                  >
                    Go Back
                  </button>

                  <Link
                    href="/users"
                    className="rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
                  >
                    Users List
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const location = [user.city, user.state, user.country]
    .filter(Boolean)
    .join(', ');

  const socialLinks = user.social_links
    ? Object.entries(user.social_links).filter(
        ([, value]) => Boolean(value)
      )
    : [];

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="mx-auto max-w-6xl">
        {/* Header */}
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <Link
              href="/users"
              className="mb-3 inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900"
            >
              <ArrowLeft className="h-4 w-4" />
              Back to Users
            </Link>

            <h1 className="text-2xl font-bold text-gray-900">
              User Details
            </h1>

            <p className="mt-1 text-sm text-gray-500">
              View complete profile information and account status.
            </p>
          </div>

          <Link
            href={`/users/${user.id}/edit`}
            className="inline-flex items-center justify-center gap-2 rounded-lg bg-gray-900 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-gray-800"
          >
            <Edit className="h-4 w-4" />
            Edit User
          </Link>
        </div>

        {/* Profile Header */}
        <div className="mb-6 overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="h-24 bg-gradient-to-r from-gray-900 to-gray-700" />

          <div className="px-6 pb-6">
            <div className="-mt-12 flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
                <div className="flex h-24 w-24 shrink-0 items-center justify-center overflow-hidden rounded-full border-4 border-white bg-gray-100 shadow-sm">
                  {user.photo_url ? (
                    <img
                      src={user.photo_url}
                      alt={user.name || user.username || 'User'}
                      className="h-full w-full object-cover"
                      onError={(event) => {
                        event.currentTarget.style.display = 'none';
                      }}
                    />
                  ) : (
                    <UserIcon className="h-10 w-10 text-gray-400" />
                  )}
                </div>

                <div className="pb-1">
                  <h2 className="text-xl font-bold text-gray-900">
                    {displayValue(user.name)}
                  </h2>

                  <div className="mt-1 flex flex-wrap items-center gap-3 text-sm text-gray-500">
                    <span className="inline-flex items-center gap-1">
                      <AtSign className="h-4 w-4" />
                      {displayValue(user.username)}
                    </span>

                    {user.email && (
                      <span className="inline-flex items-center gap-1">
                        <Mail className="h-4 w-4" />
                        {user.email}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <span
                  className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium ${
                    user.is_active
                      ? 'bg-green-100 text-green-700'
                      : 'bg-red-100 text-red-700'
                  }`}
                >
                  {user.is_active ? (
                    <CheckCircle className="h-3.5 w-3.5" />
                  ) : (
                    <XCircle className="h-3.5 w-3.5" />
                  )}

                  {user.is_active ? 'Active' : 'Suspended'}
                </span>

                <span className="inline-flex items-center gap-1.5 rounded-full bg-purple-100 px-3 py-1.5 text-xs font-medium capitalize text-purple-700">
                  <Shield className="h-3.5 w-3.5" />
                  {displayValue(user.role)}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Left / Main */}
          <div className="space-y-6 lg:col-span-2">
            {/* Basic Information */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-5 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <UserIcon className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h3 className="font-semibold text-gray-900">
                    Basic Information
                  </h3>

                  <p className="text-xs text-gray-500">
                    User profile information
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <InfoItem
                  icon={<UserIcon className="h-4 w-4" />}
                  label="Full Name"
                  value={displayValue(user.name)}
                />

                <InfoItem
                  icon={<AtSign className="h-4 w-4" />}
                  label="Username"
                  value={displayValue(user.username)}
                />

                <InfoItem
                  icon={<Mail className="h-4 w-4" />}
                  label="Email"
                  value={displayValue(user.email)}
                />

                <InfoItem
                  icon={<Gamepad2 className="h-4 w-4" />}
                  label="Preferred Game"
                  value={displayValue(user.preferred_game)}
                />

                <InfoItem
                  icon={<Hash className="h-4 w-4" />}
                  label="In-Game UID"
                  value={displayValue(user.in_game_uid)}
                />

                <InfoItem
                  icon={<MapPin className="h-4 w-4" />}
                  label="Location"
                  value={location || 'Not provided'}
                />
              </div>
            </section>

            {/* Bio */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-4">
                <h3 className="font-semibold text-gray-900">
                  Bio
                </h3>

                <p className="mt-1 text-xs text-gray-500">
                  User-provided profile description
                </p>
              </div>

              <div className="rounded-lg bg-gray-50 p-4">
                <p className="whitespace-pre-wrap text-sm leading-6 text-gray-700">
                  {displayValue(user.bio)}
                </p>
              </div>
            </section>

            {/* Location */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-5 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <MapPin className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h3 className="font-semibold text-gray-900">
                    Location
                  </h3>

                  <p className="text-xs text-gray-500">
                    User location details
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-5 sm:grid-cols-3">
                <InfoItem
                  icon={<Globe className="h-4 w-4" />}
                  label="Country"
                  value={displayValue(user.country)}
                />

                <InfoItem
                  icon={<MapPin className="h-4 w-4" />}
                  label="State"
                  value={displayValue(user.state)}
                />

                <InfoItem
                  icon={<MapPin className="h-4 w-4" />}
                  label="City"
                  value={displayValue(user.city)}
                />
              </div>
            </section>

            {/* Social Links */}
            {socialLinks.length > 0 && (
              <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
                <div className="mb-5">
                  <h3 className="font-semibold text-gray-900">
                    Social Links
                  </h3>

                  <p className="mt-1 text-xs text-gray-500">
                    Public social profiles connected to this account
                  </p>
                </div>

                <div className="space-y-3">
                  {socialLinks.map(([platform, value]) => (
                    <div
                      key={platform}
                      className="flex flex-col gap-1 rounded-lg border border-gray-100 bg-gray-50 p-3 sm:flex-row sm:items-center sm:justify-between"
                    >
                      <span className="text-sm font-medium capitalize text-gray-700">
                        {platform}
                      </span>

                      <a
                        href={value}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="break-all text-sm text-blue-600 hover:underline"
                      >
                        {value}
                      </a>
                    </div>
                  ))}
                </div>
              </section>
            )}
          </div>

          {/* Right / Account Information */}
          <div className="space-y-6">
            {/* Account Status */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="mb-5 font-semibold text-gray-900">
                Account
              </h3>

              <div className="space-y-4">
                <StatusRow
                  label="Status"
                  value={user.is_active ? 'Active' : 'Suspended'}
                  active={user.is_active}
                />

                <div className="border-t border-gray-100 pt-4">
                  <p className="mb-1 text-xs font-medium uppercase tracking-wide text-gray-400">
                    Role
                  </p>

                  <div className="flex items-center gap-2">
                    <Shield className="h-4 w-4 text-purple-600" />
                    <span className="text-sm font-medium capitalize text-gray-900">
                      {displayValue(user.role)}
                    </span>
                  </div>
                </div>
              </div>
            </section>

            {/* Account Dates */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="mb-5 font-semibold text-gray-900">
                Account Dates
              </h3>

              <div className="space-y-5">
                <div>
                  <div className="mb-1 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                    <Calendar className="h-3.5 w-3.5" />
                    Created
                  </div>

                  <p className="text-sm font-medium text-gray-900">
                    {formatDate(user.created_at)}
                  </p>
                </div>

                <div className="border-t border-gray-100 pt-5">
                  <div className="mb-1 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                    <Calendar className="h-3.5 w-3.5" />
                    Last Updated
                  </div>

                  <p className="text-sm font-medium text-gray-900">
                    {formatDate(user.updated_at)}
                  </p>
                </div>
              </div>
            </section>

            {/* User ID */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="mb-3 font-semibold text-gray-900">
                User ID
              </h3>

              <div className="rounded-lg bg-gray-50 p-3">
                <p className="break-all font-mono text-xs text-gray-600">
                  {user.id}
                </p>
              </div>
            </section>

            {/* Edit Action */}
            <Link
              href={`/users/${user.id}/edit`}
              className="flex w-full items-center justify-center gap-2 rounded-lg bg-gray-900 px-4 py-3 text-sm font-medium text-white transition hover:bg-gray-800"
            >
              <Edit className="h-4 w-4" />
              Edit User
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}

function InfoItem({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div>
      <div className="mb-1.5 flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-gray-400">
        {icon}
        {label}
      </div>

      <p className="break-words text-sm font-medium text-gray-900">
        {value}
      </p>
    </div>
  );
}

function StatusRow({
  label,
  value,
  active,
}: {
  label: string;
  value: string;
  active: boolean;
}) {
  return (
    <div>
      <p className="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
        {label}
      </p>

      <span
        className={`inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-medium ${
          active
            ? 'bg-green-100 text-green-700'
            : 'bg-red-100 text-red-700'
        }`}
      >
        {active ? (
          <CheckCircle className="h-3.5 w-3.5" />
        ) : (
          <XCircle className="h-3.5 w-3.5" />
        )}

        {value}
      </span>
    </div>
  );
}