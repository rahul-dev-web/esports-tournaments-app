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
    <div className="rounded-[24px] border border-white/10 bg-white/5 p-6 shadow-2xl shadow-black/20 backdrop-blur-xl">
      <div className="flex justify-between items-start">
        <div>
          <p className="text-sm font-medium text-white/60">{label}</p>
          <h3 className="mt-2 text-3xl font-bold text-white">{value}</h3>
          {trend && (
            <div className="flex items-center gap-2 mt-2">
              <TrendingUp size={16} className="text-emerald-300" />
              <span className="text-sm text-emerald-300">{trend}% this month</span>
            </div>
          )}
        </div>
        {icon && <div className="text-cyan-300">{icon}</div>}
      </div>
    </div>
  );
}
