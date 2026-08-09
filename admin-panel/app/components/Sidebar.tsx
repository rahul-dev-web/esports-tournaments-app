'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
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

interface MenuItem {
  label: string;
  href: string;
  icon: React.ReactNode;
}

export default function Sidebar() {
  const pathname = usePathname();

  const menuItems: MenuItem[] = [
    { label: 'Dashboard', href: '/dashboard', icon: <Home size={20} /> },
    { label: 'Tournaments', href: '/tournaments', icon: <Trophy size={20} /> },
    { label: 'Users', href: '/users', icon: <Users size={20} /> },
    { label: 'Teams', href: '/teams', icon: <Users2 size={20} /> },
    { label: 'Registrations', href: '/registrations', icon: <FileText size={20} /> },
    { label: 'Settings', href: '/settings', icon: <Settings size={20} /> },
  ];

  return (
    <aside className="w-64 bg-gradient-to-b from-purple-900 to-purple-800 text-white min-h-screen p-6">
      {/* Logo */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-purple-200">ARENAHUB</h1>
        <p className="text-sm text-purple-300">Admin Panel</p>
      </div>

      {/* Navigation */}
      <nav className="space-y-2">
        {menuItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={clsx(
              'flex items-center gap-3 px-4 py-3 rounded-lg transition-colors',
              pathname === item.href
                ? 'bg-white bg-opacity-20 text-white'
                : 'text-purple-100 hover:bg-white hover:bg-opacity-10'
            )}
          >
            {item.icon}
            <span>{item.label}</span>
          </Link>
        ))}
      </nav>

      {/* Footer */}
      <div className="mt-auto pt-6 border-t border-purple-700">
        <button className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-purple-100 hover:bg-white hover:bg-opacity-10 transition-colors">
          <LogOut size={20} />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}