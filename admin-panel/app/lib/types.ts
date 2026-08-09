/**
 * TypeScript types for Admin Panel
 */

export interface User {
  id: string;
  email: string;
  name: string;
  username: string;
  role: 'user' | 'admin';
  bio?: string;
  country?: string;
  city?: string;
  photo_url?: string;
  created_at: string;
}

export interface Tournament {
  id: string;
  name: string;
  game: string;
  mode: 'solo' | 'duo' | 'squad' | 'custom';
  starts_at: string;
  entry_requirement?: string;
  reward?: string;
  total_slots: number;
  registered_teams: number;
  ads_required: number;
  policy: 'individual_ads' | 'captain_ads';
  status: 'draft' | 'published' | 'closed';
  created_at: string;
}

export interface Team {
  id: string;
  name: string;
  game: string;
  logo_url?: string;
  captain_id: string;
  is_private: boolean;
  created_at: string;
}

export interface Registration {
  id: string;
  tournament_id: string;
  team_id: string;
  captain_id: string;
  status: 'pending' | 'ad_verification' | 'registered' | 'rejected';
  ads_required: number;
  ads_completed: number;
  completed_by: string[];
  slot?: number;
}

export interface DashboardStats {
  total_users: number;
  total_teams: number;
  total_registrations: number;
  active_tournaments: number;
}

export interface CreateTournamentRequest {
  name: string;
  game: string;
  mode: 'solo' | 'duo' | 'squad' | 'custom';
  starts_at: string;
  entry_requirement?: string;
  reward?: string;
  total_slots: number;
  ads_required: number;
  policy: 'individual_ads' | 'captain_ads';
}

export interface Settings {
  registration_policy: 'individual_ads' | 'captain_ads';
  max_team_size: number;
  ads_per_registration: number;
  registration_timeout_hours: number;
}