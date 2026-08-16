'use client';

import React from 'react';
import Link from 'next/link';
import { useRouter, usePathname } from 'next/navigation';
import {
  Home,
  Trophy,
  Users,
  Users2,
  FileText,
  Settings,
  LogOut,
} from 'lucide-react';
import clsx from 'clsx';
import { supabase } from '../lib/supabase';

interface MenuItem {
  label: string;
  href: string;
  icon: React.ReactNode;
}

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const menuItems: MenuItem[] = [
    { label: 'Dashboard', href: '/dashboard', icon: <Home size={19} /> },
    { label: 'Tournaments', href: '/tournaments', icon: <Trophy size={19} /> },
    { label: 'Users', href: '/users', icon: <Users size={19} /> },
    { label: 'Teams', href: '/teams', icon: <Users2 size={19} /> },
    { label: 'Registrations', href: '/registrations', icon: <FileText size={19} /> },
    { label: 'Settings', href: '/settings', icon: <Settings size={19} /> },
  ];

  const logout = async () => {
    localStorage.removeItem('adminToken');
    if (supabase) await supabase.auth.signOut();
    router.push('/login');
  };

  return (
    <>
      <aside className="hidden w-64 shrink-0 flex-col bg-gradient-to-b from-purple-950 via-purple-900 to-purple-950 p-5 text-white md:flex">
        <div className="mb-7 px-1">
          <h1 className="text-xl font-bold tracking-wide text-purple-100">ARENAHUB</h1>
          <p className="text-xs text-purple-300">Admin Panel</p>
        </div>

        <nav className="flex-1 space-y-1.5">
          {menuItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={clsx(
                'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors',
                pathname === item.href
                  ? 'bg-white/15 text-white shadow-sm'
                  : 'text-purple-100/85 hover:bg-white/10 hover:text-white'
              )}
            >
              {item.icon}
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>

        <div className="mt-6 border-t border-purple-700/60 pt-4">
          <button
            className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm text-purple-100/85 transition-colors hover:bg-white/10 hover:text-white"
            onClick={logout}
          >
            <LogOut size={19} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      <nav className="fixed inset-x-2 bottom-2 z-50 rounded-2xl border border-white/10 bg-[#0b1222]/95 px-1.5 pt-1.5 pb-[max(6px,env(safe-area-inset-bottom))] shadow-2xl shadow-black/40 backdrop-blur-xl md:hidden">
        <div className="grid grid-cols-6 gap-0.5">
          {menuItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              aria-label={item.label}
              className={clsx(
                'flex min-h-12 min-w-0 flex-col items-center justify-center gap-0.5 rounded-xl px-1 py-1.5 text-[10px] font-medium transition-colors',
                pathname === item.href
                  ? 'bg-white/15 text-white'
                  : 'text-white/55 hover:bg-white/10 hover:text-white'
              )}
            >
              {item.icon}
              <span className="max-w-full truncate">{item.label}</span>
            </Link>
          ))}
        </div>
      </nav>
    </>
  );
}
