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
    <div className="bg-white rounded-lg shadow-sm p-6 border border-gray-200">
      <div className="flex justify-between items-start">
        <div>
          <p className="text-gray-500 text-sm font-medium">{label}</p>
          <h3 className="text-3xl font-bold text-gray-900 mt-2">{value}</h3>
          {trend && (
            <div className="flex items-center gap-2 mt-2">
              <TrendingUp size={16} className="text-green-600" />
              <span className="text-sm text-green-600">{trend}% this month</span>
            </div>
          )}
        </div>
        {icon && <div className="text-purple-600">{icon}</div>}
      </div>
    </div>
  );
}