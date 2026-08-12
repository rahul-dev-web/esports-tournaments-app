'use client';

import React from 'react';
import { Bell, Settings, User } from 'lucide-react';

interface HeaderProps {
  title: string;
  subtitle?: string;
}

export default function Header({ title, subtitle }: HeaderProps) {
  return (
    <header className="border-b border-white/10 bg-white/5 px-8 py-6 backdrop-blur-xl">
      <div className="flex justify-between items-center">
        {/* Title */}
        <div>
          <h1 className="text-3xl font-bold text-white">{title}</h1>
          {subtitle && <p className="mt-1 text-white/65">{subtitle}</p>}
        </div>

        {/* Right Actions */}
        <div className="flex items-center gap-6">
          <button className="rounded-lg p-2 hover:bg-white/10">
            <Bell size={20} className="text-white/75" />
          </button>
          <button className="rounded-lg p-2 hover:bg-white/10">
            <Settings size={20} className="text-white/75" />
          </button>
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-cyan-400 shadow-lg shadow-violet-500/25">
            <User size={20} className="text-white" />
          </div>
        </div>
      </div>
    </header>
  );
}
