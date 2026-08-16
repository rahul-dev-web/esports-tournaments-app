'use client';

import React from 'react';
import { Bell, Settings, User } from 'lucide-react';

interface HeaderProps {
  title: string;
  subtitle?: string;
}

export default function Header({ title, subtitle }: HeaderProps) {
  return (
    <header className="sticky top-0 z-40 border-b border-white/10 bg-[#07101f]/90 px-3 py-3 backdrop-blur-xl sm:px-4 sm:py-4 md:static md:px-6 md:py-5 lg:px-8">
      <div className="flex min-w-0 items-center justify-between gap-3">
        <div className="min-w-0">
          <h1 className="truncate text-xl font-bold text-white sm:text-2xl md:text-3xl">{title}</h1>
          {subtitle && <p className="mt-0.5 truncate text-xs text-white/60 sm:text-sm">{subtitle}</p>}
        </div>
        <div className="flex shrink-0 items-center gap-1 sm:gap-2 md:gap-4">
          <button aria-label="Notifications" className="rounded-lg p-2 hover:bg-white/10">
            <Bell size={18} className="text-white/75" />
          </button>
          <button aria-label="Settings" className="rounded-lg p-2 hover:bg-white/10">
            <Settings size={18} className="text-white/75" />
          </button>
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-cyan-400 shadow-lg shadow-violet-500/20 sm:h-9 sm:w-9">
            <User size={17} className="text-white" />
          </div>
        </div>
      </div>
    </header>
  );
}
