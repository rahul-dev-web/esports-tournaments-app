'use client';

import React from 'react';
import Sidebar from './Sidebar';
import Header from './Header';

interface LayoutProps {
  children: React.ReactNode;
  title: string;
  subtitle?: string;
}

export default function Layout({ children, title, subtitle }: LayoutProps) {
  return (
    <div className="flex min-h-screen bg-[radial-gradient(circle_at_top,_rgba(138,92,255,0.16),_transparent_24%),linear-gradient(180deg,#07101f_0%,#0b1328_55%,#050814_100%)] text-white">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Header title={title} subtitle={subtitle} />
        <main className="min-h-0 flex-1 overflow-auto px-3 pb-24 pt-4 sm:px-4 sm:pt-5 md:px-6 md:pb-8 md:pt-6 lg:px-8">
          {children}
        </main>
      </div>
    </div>
  );
}
