'use client';

import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import { User } from '../lib/types';
import { usersAPI } from '../lib/api';
import { Eye, Edit2 } from 'lucide-react';
import Link from 'next/link';

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const data = await usersAPI.getAll(1, 10);
      setUsers(data);
    } catch (err) {
      console.error('Error fetching users:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (query: string) => {
    setSearch(query);
    if (query.length > 0) {
      try {
        const data = await usersAPI.search(query);
        setUsers(data);
      } catch (err) {
        console.error('Error searching users:', err);
      }
    } else {
      fetchUsers();
    }
  };

  return (
    <Layout title="Users" subtitle="Manage platform users">
      <div className="mb-4 sm:mb-6">
        <input
          type="text"
          placeholder="Search users by name, email, or username..."
          value={search}
          onChange={(e) => handleSearch(e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-600 sm:text-base"
        />
      </div>

      {/* Desktop/tablet table. Mobile uses compact cards to keep actions inside the viewport. */}
      <div className="hidden overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm sm:block">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[680px]">
            <thead className="border-b border-gray-200 bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Name</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Email</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Role</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Joined</th>
                <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {loading ? (
                <tr><td colSpan={5} className="px-6 py-4 text-center text-gray-500">Loading users...</td></tr>
              ) : users.length === 0 ? (
                <tr><td colSpan={5} className="px-6 py-4 text-center text-gray-500">No users found</td></tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">{user.name}</td>
                    <td className="px-6 py-4 text-sm text-gray-600">{user.email}</td>
                    <td className="px-6 py-4 text-sm"><span className={`rounded px-2 py-1 text-xs font-medium ${user.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-gray-100 text-gray-800'}`}>{user.role}</span></td>
                    <td className="px-6 py-4 text-sm text-gray-600">{new Date(user.created_at).toLocaleDateString()}</td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex justify-end gap-2">
                        <Link href={`/users/${user.id}`} className="rounded p-2 hover:bg-gray-100" aria-label="View user"><Eye size={16} className="text-gray-600" /></Link>
                        <Link href={`/users/${user.id}/edit`} className="rounded p-2 hover:bg-gray-100" aria-label="Edit user"><Edit2 size={16} className="text-gray-600" /></Link>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="space-y-3 sm:hidden">
        {loading ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-center text-sm text-gray-500">Loading users...</div>
        ) : users.length === 0 ? (
          <div className="rounded-xl border border-gray-200 bg-white px-4 py-6 text-center text-sm text-gray-500">No users found</div>
        ) : (
          users.map((user) => (
            <article key={user.id} className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <h3 className="break-words text-sm font-semibold leading-5 text-gray-900">{user.name}</h3>
                  <p className="mt-1 break-all text-xs text-gray-500">{user.email}</p>
                </div>
                <span className={`shrink-0 rounded px-2 py-1 text-[10px] font-medium ${user.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-gray-100 text-gray-800'}`}>{user.role}</span>
              </div>

              <div className="mt-3 flex items-center justify-between border-t border-gray-100 pt-3">
                <div>
                  <p className="text-[10px] text-gray-400">Joined</p>
                  <p className="mt-0.5 text-xs font-medium text-gray-700">{new Date(user.created_at).toLocaleDateString()}</p>
                </div>
                <div className="flex gap-2">
                  <Link href={`/users/${user.id}`} className="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50" aria-label="View user"><Eye size={14} />View</Link>
                  <Link href={`/users/${user.id}/edit`} className="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50" aria-label="Edit user"><Edit2 size={14} />Edit</Link>
                </div>
              </div>
            </article>
          ))
        )}
      </div>
    </Layout>
  );
}