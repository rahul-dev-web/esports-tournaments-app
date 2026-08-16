'use client';

import React from 'react';
import { TrendingUp } from 'lucide-react';

interface StatsCardProps {
  label: string;
  value: number | string;
  trend?: number;
  icon?: React.ReactNode;
}

export default function StatsCard({ label, value, trend, icon }: StatsCardProps) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-3 shadow-xl shadow-black/20 backdrop-blur-xl sm:rounded-[24px] sm:p-6 sm:shadow-2xl">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate text-[11px] font-medium text-white/60 sm:text-sm">{label}</p>
          <h3 className="mt-1 text-2xl font-bold leading-none text-white sm:mt-2 sm:text-3xl">{value}</h3>
          {trend ? (
            <div className="mt-1.5 hidden items-center gap-2 sm:flex">
              <TrendingUp size={16} className="text-emerald-300" />
              <span className="text-sm text-emerald-300">{trend}% this month</span>
            </div>
          ) : null}
        </div>
        {icon ? <div className="shrink-0 text-cyan-300 [&>svg]:h-5 [&>svg]:w-5 sm:[&>svg]:h-6 sm:[&>svg]:w-6">{icon}</div> : null}
      </div>
    </div>
  );
}
