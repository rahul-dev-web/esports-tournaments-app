'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  ArrowLeft,
  Save,
  Loader2,
  AlertCircle,
  User as UserIcon,
  Mail,
  AtSign,
  MapPin,
  Globe,
  Gamepad2,
  Hash,
  Image as ImageIcon,
  Link2,
  FileText,
  CheckCircle,
} from 'lucide-react';

import { usersAPI } from '../../../lib/api';

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

interface FormData {
  name: string;
  username: string;
  bio: string;
  country: string;
  state: string;
  city: string;
  photo_url: string;
  preferred_game: string;
  in_game_uid: string;
  social_links: string;
}

function getErrorMessage(error: any): string {
  const detail = error?.response?.data?.detail;

  if (Array.isArray(detail)) {
    return detail
      .map((item: any) => item?.msg || String(item))
      .join(', ');
  }

  if (typeof detail === 'string' && detail.trim()) {
    return detail;
  }

  if (
    typeof error?.response?.data?.message === 'string' &&
    error.response.data.message.trim()
  ) {
    return error.response.data.message;
  }

  if (error?.response?.status === 401) {
    return 'Your admin session has expired. Please log in again.';
  }

  if (error?.response?.status === 403) {
    return 'You do not have permission to edit users.';
  }

  if (error?.response?.status === 404) {
    return 'User not found.';
  }

  if (error?.response?.status === 409) {
    return 'This username is already taken or conflicts with existing data.';
  }

  return 'Something went wrong while saving the user.';
}

function convertUserToFormData(user: UserDetails): FormData {
  return {
    name: user.name ?? '',
    username: user.username ?? '',
    bio: user.bio ?? '',
    country: user.country ?? '',
    state: user.state ?? '',
    city: user.city ?? '',
    photo_url: user.photo_url ?? '',
    preferred_game: user.preferred_game ?? '',
    in_game_uid: user.in_game_uid ?? '',
    social_links: user.social_links
      ? JSON.stringify(user.social_links, null, 2)
      : '',
  };
}

function parseSocialLinks(value: string): Record<string, string> | undefined {
  const trimmed = value.trim();

  if (!trimmed) {
    return undefined;
  }

  let parsed: unknown;

  try {
    parsed = JSON.parse(trimmed);
  } catch {
    throw new Error(
      'Social Links must contain valid JSON, for example {"discord":"https://discord.com/..."}'
    );
  }

  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    Array.isArray(parsed)
  ) {
    throw new Error('Social Links must be a JSON object.');
  }

  const result: Record<string, string> = {};

  for (const [key, item] of Object.entries(
    parsed as Record<string, unknown>
  )) {
    if (typeof item !== 'string') {
      throw new Error(
        `Social link "${key}" must have a string URL/value.`
      );
    }

    result[key] = item;
  }

  return result;
}

export default function EditUserPage() {
  const params = useParams();
  const router = useRouter();

  const userId = Array.isArray(params?.id)
    ? params.id[0]
    : params?.id;

  const [user, setUser] = useState<UserDetails | null>(null);
  const [formData, setFormData] = useState<FormData>({
    name: '',
    username: '',
    bio: '',
    country: '',
    state: '',
    city: '',
    photo_url: '',
    preferred_game: '',
    in_game_uid: '',
    social_links: '',
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

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

        if (cancelled) {
          return;
        }

        const userData = data as UserDetails;

        setUser(userData);
        setFormData(convertUserToFormData(userData));
      } catch (err: any) {
        if (cancelled) {
          return;
        }

        setError(getErrorMessage(err));
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

  function handleChange(
    field: keyof FormData,
    value: string
  ) {
    setFormData((current) => ({
      ...current,
      [field]: value,
    }));

    if (error) {
      setError(null);
    }

    if (success) {
      setSuccess(null);
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!userId || typeof userId !== 'string') {
      setError('Invalid user ID.');
      return;
    }

    const username = formData.username.trim();

    if (!username) {
      setError('Username is required.');
      return;
    }

    if (username.length > 20) {
      setError('Username must not exceed 20 characters.');
      return;
    }

    let socialLinks: Record<string, string> | undefined;

    try {
      socialLinks = parseSocialLinks(formData.social_links);
    } catch (err: any) {
      setError(
        err?.message || 'Social Links JSON is invalid.'
      );
      return;
    }

    const payload = {
      name: formData.name.trim(),
      username,
      bio: formData.bio,
      country: formData.country.trim(),
      state: formData.state.trim(),
      city: formData.city.trim(),
      photo_url: formData.photo_url.trim() || null,
      preferred_game: formData.preferred_game.trim(),
      in_game_uid:
        formData.in_game_uid.trim() || null,
      social_links: socialLinks,
    };

    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      const updatedUser = await usersAPI.update(
        userId,
        payload
      );

      const normalizedUser =
        updatedUser as UserDetails;

      setUser(normalizedUser);
      setFormData(convertUserToFormData(normalizedUser));
      setSuccess('User profile updated successfully.');

      /*
       * Keep the user on the edit page after saving.
       * This avoids losing the success message and lets the
       * admin verify the updated values immediately.
       */
    } catch (err: any) {
      setError(getErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  function handleCancel() {
    router.push(`/users/${userId}`);
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="mx-auto max-w-5xl">
          <div className="flex min-h-[60vh] items-center justify-center">
            <div className="flex flex-col items-center gap-3 text-gray-600">
              <Loader2 className="h-8 w-8 animate-spin" />
              <p className="text-sm">
                Loading user information...
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (error && !user) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="mx-auto max-w-5xl">
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
                  {error}
                </p>

                <div className="mt-5 flex flex-wrap gap-3">
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

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="mx-auto max-w-5xl">
        {/* Header */}
        <div className="mb-6">
          <Link
            href={`/users/${userId}`}
            className="mb-3 inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to User
          </Link>

          <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                Edit User
              </h1>

              <p className="mt-1 text-sm text-gray-500">
                Update the user&apos;s profile information.
              </p>
            </div>

            {user && (
              <div className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-600">
                <UserIcon className="h-4 w-4" />

                <span>
                  Editing{' '}
                  <span className="font-medium text-gray-900">
                    {user.username || user.email}
                  </span>
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div className="mb-6 flex items-start gap-3 rounded-xl border border-red-200 bg-red-50 p-4">
            <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-red-600" />

            <div>
              <p className="text-sm font-medium text-red-800">
                Unable to save changes
              </p>

              <p className="mt-1 text-sm text-red-700">
                {error}
              </p>
            </div>
          </div>
        )}

        {/* Success */}
        {success && (
          <div className="mb-6 flex items-start gap-3 rounded-xl border border-green-200 bg-green-50 p-4">
            <CheckCircle className="mt-0.5 h-5 w-5 shrink-0 text-green-600" />

            <div>
              <p className="text-sm font-medium text-green-800">
                Changes saved
              </p>

              <p className="mt-1 text-sm text-green-700">
                {success}
              </p>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="space-y-6">
            {/* Basic Information */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-6 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <UserIcon className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h2 className="font-semibold text-gray-900">
                    Basic Information
                  </h2>

                  <p className="text-xs text-gray-500">
                    Editable profile information
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
                {/* Name */}
                <FormField
                  label="Full Name"
                  icon={<UserIcon className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(event) =>
                      handleChange(
                        'name',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="Enter full name"
                  />
                </FormField>

                {/* Username */}
                <FormField
                  label="Username"
                  icon={<AtSign className="h-4 w-4" />}
                  required
                >
                  <input
                    type="text"
                    value={formData.username}
                    onChange={(event) =>
                      handleChange(
                        'username',
                        event.target.value
                      )
                    }
                    maxLength={20}
                    required
                    className="form-input"
                    placeholder="Enter username"
                  />

                  <p className="mt-1 text-xs text-gray-400">
                    Maximum 20 characters.
                  </p>
                </FormField>

                {/* Email - read only */}
                <FormField
                  label="Email"
                  icon={<Mail className="h-4 w-4" />}
                >
                  <input
                    type="email"
                    value={user?.email ?? ''}
                    disabled
                    readOnly
                    className="form-input cursor-not-allowed bg-gray-100 text-gray-500"
                  />

                  <p className="mt-1 text-xs text-gray-400">
                    Email cannot be changed from the admin panel.
                  </p>
                </FormField>

                {/* Preferred Game */}
                <FormField
                  label="Preferred Game"
                  icon={<Gamepad2 className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.preferred_game}
                    onChange={(event) =>
                      handleChange(
                        'preferred_game',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="e.g. Free Fire"
                  />
                </FormField>

                {/* In-game UID */}
                <FormField
                  label="In-Game UID"
                  icon={<Hash className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.in_game_uid}
                    onChange={(event) =>
                      handleChange(
                        'in_game_uid',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="Enter in-game UID"
                  />
                </FormField>

                {/* Photo URL */}
                <FormField
                  label="Photo URL"
                  icon={<ImageIcon className="h-4 w-4" />}
                >
                  <input
                    type="url"
                    value={formData.photo_url}
                    onChange={(event) =>
                      handleChange(
                        'photo_url',
                        event.target.value
                      )
                    }
                    maxLength={1000}
                    className="form-input"
                    placeholder="https://example.com/photo.jpg"
                  />
                </FormField>
              </div>
            </section>

            {/* Bio */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-5 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <FileText className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h2 className="font-semibold text-gray-900">
                    Bio
                  </h2>

                  <p className="text-xs text-gray-500">
                    User profile description
                  </p>
                </div>
              </div>

              <textarea
                value={formData.bio}
                onChange={(event) =>
                  handleChange(
                    'bio',
                    event.target.value
                  )
                }
                rows={6}
                className="form-input resize-y"
                placeholder="Enter user's bio"
              />
            </section>

            {/* Location */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-6 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <MapPin className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h2 className="font-semibold text-gray-900">
                    Location
                  </h2>

                  <p className="text-xs text-gray-500">
                    User location information
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
                {/* Country */}
                <FormField
                  label="Country"
                  icon={<Globe className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.country}
                    onChange={(event) =>
                      handleChange(
                        'country',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="Country"
                  />
                </FormField>

                {/* State */}
                <FormField
                  label="State"
                  icon={<MapPin className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.state}
                    onChange={(event) =>
                      handleChange(
                        'state',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="State"
                  />
                </FormField>

                {/* City */}
                <FormField
                  label="City"
                  icon={<MapPin className="h-4 w-4" />}
                >
                  <input
                    type="text"
                    value={formData.city}
                    onChange={(event) =>
                      handleChange(
                        'city',
                        event.target.value
                      )
                    }
                    maxLength={100}
                    className="form-input"
                    placeholder="City"
                  />
                </FormField>
              </div>
            </section>

            {/* Social Links */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-5 flex items-center gap-3">
                <div className="rounded-lg bg-gray-100 p-2">
                  <Link2 className="h-5 w-5 text-gray-700" />
                </div>

                <div>
                  <h2 className="font-semibold text-gray-900">
                    Social Links
                  </h2>

                  <p className="text-xs text-gray-500">
                    Social links stored as a JSON object
                  </p>
                </div>
              </div>

              <textarea
                value={formData.social_links}
                onChange={(event) =>
                  handleChange(
                    'social_links',
                    event.target.value
                  )
                }
                rows={7}
                className="form-input resize-y font-mono text-sm"
                placeholder={`{
  "discord": "https://discord.com/...",
  "instagram": "https://instagram.com/..."
}`}
              />

              <p className="mt-2 text-xs text-gray-400">
                Example: {'{"discord":"https://discord.com/..."}'}
              </p>
            </section>

            {/* Account Information */}
            <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="mb-5">
                <h2 className="font-semibold text-gray-900">
                  Account Information
                </h2>

                <p className="mt-1 text-xs text-gray-500">
                  These fields are intentionally read-only.
                </p>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
                <ReadOnlyValue
                  label="Role"
                  value={user?.role || '—'}
                />

                <ReadOnlyValue
                  label="Account Status"
                  value={
                    user?.is_active
                      ? 'Active'
                      : 'Suspended'
                  }
                />

                <ReadOnlyValue
                  label="User ID"
                  value={user?.id || '—'}
                />
              </div>

              <div className="mt-4 rounded-lg border border-gray-200 bg-gray-50 p-4">
                <p className="text-sm text-gray-600">
                  <span className="font-medium text-gray-800">
                    Note:
                  </span>{' '}
                  Email, role, and account status are not changed
                  from this form. Account suspension is handled
                  separately by the admin user-management actions.
                </p>
              </div>
            </section>

            {/* Actions */}
            <div className="sticky bottom-4 z-10 rounded-xl border border-gray-200 bg-white/95 p-4 shadow-lg backdrop-blur">
              <div className="flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
                <button
                  type="button"
                  onClick={handleCancel}
                  disabled={saving}
                  className="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-5 py-2.5 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  disabled={saving}
                  className="inline-flex items-center justify-center gap-2 rounded-lg bg-gray-900 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {saving ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Saving...
                    </>
                  ) : (
                    <>
                      <Save className="h-4 w-4" />
                      Save Changes
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </form>
      </div>

      <style jsx>{`
        .form-input {
          width: 100%;
          border-radius: 0.5rem;
          border: 1px solid rgb(209 213 219);
          background: white;
          padding: 0.625rem 0.75rem;
          font-size: 0.875rem;
          line-height: 1.25rem;
          color: rgb(17 24 39);
          outline: none;
          transition:
            border-color 150ms ease,
            box-shadow 150ms ease;
        }

        .form-input::placeholder {
          color: rgb(156 163 175);
        }

        .form-input:focus {
          border-color: rgb(75 85 99);
          box-shadow: 0 0 0 2px rgb(229 231 235);
        }

        .form-input:disabled {
          cursor: not-allowed;
          background: rgb(243 244 246);
        }
      `}</style>
    </div>
  );
}

function FormField({
  label,
  icon,
  required = false,
  children,
}: {
  label: string;
  icon?: React.ReactNode;
  required?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div>
      <label className="mb-2 flex items-center gap-2 text-sm font-medium text-gray-700">
        {icon && (
          <span className="text-gray-500">
            {icon}
          </span>
        )}

        <span>{label}</span>

        {required && (
          <span className="text-red-500">*</span>
        )}
      </label>

      {children}
    </div>
  );
}

function ReadOnlyValue({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-lg border border-gray-200 bg-gray-50 p-4">
      <p className="text-xs font-medium uppercase tracking-wide text-gray-400">
        {label}
      </p>

      <p className="mt-1 break-all text-sm font-medium capitalize text-gray-900">
        {value}
      </p>
    </div>
  );
}