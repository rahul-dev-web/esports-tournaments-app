/**
 * API Client for Admin Panel
 * Handles all backend communication
 */

import axios, { AxiosError } from 'axios';

// Base URL - change based on environment
const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api';

// Create axios instance
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
apiClient.interceptors.request.use((config) => {
  const token = typeof window !== 'undefined' ? localStorage.getItem('adminToken') : null;

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});

// Handle errors
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (typeof window !== 'undefined' && error.response?.status === 401) {
      // Redirect to login
      window.location.href = '/login';
    }

    return Promise.reject(error);
  }
);

// ============================================================
// USERS API
// ============================================================

export const usersAPI = {
  async getAll(page = 1, limit = 10) {
    const response = await apiClient.get(
      `/admin/users?skip=${(page - 1) * limit}&limit=${limit}`
    );

    return response.data.users ?? response.data;
  },

  async getOne(userId: string) {
    const response = await apiClient.get(`/admin/users/${userId}`);

    return response.data;
  },

  async update(userId: string, data: any) {
    const response = await apiClient.patch(`/admin/users/${userId}`, data);

    return response.data;
  },

  async search(query: string) {
    const response = await apiClient.get(`/admin/users?search=${query}`);

    return response.data.users ?? response.data;
  },
};

// ============================================================
// TOURNAMENTS API
// ============================================================

export const tournamentsAPI = {
  async getAll(page = 1, limit = 10, status?: string) {
    let url = `/tournaments?skip=${(page - 1) * limit}&limit=${limit}`;

    if (status) {
      url += `&status=${status}`;
    }

    const response = await apiClient.get(url);

    return response.data;
  },

  async getOne(tournamentId: string) {
    const response = await apiClient.get(
      `/tournaments/${tournamentId}`
    );

    return response.data;
  },

  async create(data: any) {
    const response = await apiClient.post(
      '/tournaments',
      data
    );

    return response.data;
  },

  async update(tournamentId: string, data: any) {
    const response = await apiClient.patch(
      `/tournaments/${tournamentId}`,
      data
    );

    return response.data;
  },

  async delete(tournamentId: string) {
    const response = await apiClient.delete(
      `/tournaments/${tournamentId}`
    );

    return response.data;
  },

  async changeStatus(tournamentId: string, status: string) {
    const response = await apiClient.patch(
      `/tournaments/${tournamentId}/status/${status}`
    );

    return response.data;
  },
};

// ============================================================
// TEAMS API
// ============================================================

export const teamsAPI = {
  async getAll(page = 1, limit = 10) {
    const response = await apiClient.get(
      `/teams?skip=${(page - 1) * limit}&limit=${limit}`
    );

    return response.data;
  },

  async getOne(teamId: string) {
    const response = await apiClient.get(
      `/teams/${teamId}`
    );

    return response.data;
  },

  async update(teamId: string, data: any) {
    const response = await apiClient.patch(
      `/teams/${teamId}`,
      data
    );

    return response.data;
  },

  async delete(teamId: string) {
    const response = await apiClient.delete(
      `/teams/${teamId}`
    );

    return response.data;
  },
};

// ============================================================
// REGISTRATIONS API
// ============================================================

export const registrationsAPI = {
  async getTournamentRegistrations(tournamentId: string) {
    const response = await apiClient.get(
      `/registrations/tournament/${tournamentId}`
    );

    return response.data;
  },

  async getOne(registrationId: string) {
    const response = await apiClient.get(
      `/registrations/${registrationId}`
    );

    return response.data;
  },

  async getStatus(registrationId: string) {
    const response = await apiClient.get(
      `/registrations/status/${registrationId}`
    );

    return response.data;
  },

  async cancel(registrationId: string) {
    const response = await apiClient.post(
      `/registrations/${registrationId}/cancel`
    );

    return response.data;
  },
};

// ============================================================
// ADMIN API
// ============================================================

export const adminAPI = {
  // ----------------------------------------------------------
  // SETTINGS
  // ----------------------------------------------------------

  async getSettings() {
    const response = await apiClient.get(
      '/admin/settings'
    );

    return response.data;
  },

  async getSetting(key: string) {
    const response = await apiClient.get(
      `/admin/settings/${key}`
    );

    return response.data;
  },

  async updateSetting(key: string, data: any) {
    const response = await apiClient.patch(
      `/admin/settings/${key}`,
      data
    );

    return response.data;
  },

  // ----------------------------------------------------------
  // USER MANAGEMENT
  // ----------------------------------------------------------

  async suspendUser(userId: string) {
    const response = await apiClient.patch(
      `/admin/users/${userId}/suspend`
    );

    return response.data;
  },

  async unsuspendUser(userId: string) {
    const response = await apiClient.patch(
      `/admin/users/${userId}/unsuspend`
    );

    return response.data;
  },

  // ----------------------------------------------------------
  // REGISTRATION MANAGEMENT
  // ----------------------------------------------------------

  async approveRegistration(registrationId: string) {
    const response = await apiClient.patch(
      `/admin/registrations/${registrationId}/approve`
    );

    return response.data;
  },

  async rejectRegistration(registrationId: string) {
    const response = await apiClient.patch(
      `/admin/registrations/${registrationId}/reject`
    );

    return response.data;
  },

  async exportRegistrations(tournamentId?: string) {
    let url = '/admin/registrations/export';

    if (tournamentId) {
      url += `?tournament_id=${tournamentId}`;
    }

    const response = await apiClient.get(url);

    return response.data;
  },

  // ----------------------------------------------------------
  // TOURNAMENT MANAGEMENT
  // ----------------------------------------------------------

  async changeTournamentStatus(
    tournamentId: string,
    status: string
  ) {
    const response = await apiClient.patch(
      `/admin/tournaments/${tournamentId}/status/${status}`
    );

    return response.data;
  },

  async updateTournamentConfig(
    tournamentId: string,
    data: any
  ) {
    const response = await apiClient.patch(
      `/admin/tournaments/${tournamentId}/config`,
      data
    );

    return response.data;
  },

  // ----------------------------------------------------------
  // TEAM MANAGEMENT
  // ----------------------------------------------------------

  async getTeams(
    skip = 0,
    limit = 10,
    game?: string
  ) {
    let url = `/admin/teams?skip=${skip}&limit=${limit}`;

    if (game) {
      url += `&game=${game}`;
    }

    const response = await apiClient.get(url);

    return response.data;
  },

  async getTeamDetails(teamId: string) {
    const response = await apiClient.get(
      `/admin/teams/${teamId}`
    );

    return response.data;
  },
};

export default apiClient;
