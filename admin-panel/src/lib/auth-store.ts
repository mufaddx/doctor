'use client';

import { create } from 'zustand';
import { api, tokenStore } from './api-client';
import type { AdminUser } from './types';

interface AuthState {
  user: AdminUser | null;
  status: 'unknown' | 'authenticated' | 'unauthenticated';
  isSubmitting: boolean;
  error: string | null;
  login: (phone: string, password: string) => Promise<boolean>;
  restoreSession: () => Promise<void>;
  logout: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  status: 'unknown',
  isSubmitting: false,
  error: null,

  login: async (phone, password) => {
    set({ isSubmitting: true, error: null });

    try {
      const data = await api.post<{
        accessToken: string;
        refreshToken: string;
        user: AdminUser;
      }>('/auth/login', { phone, password });

      // Only staff accounts may enter the panel, even with valid credentials
      if (data.user.role !== 'ADMIN' && data.user.role !== 'SUPER_ADMIN') {
        set({
          isSubmitting: false,
          error: 'This account does not have admin access.',
        });
        return false;
      }

      tokenStore.set(data.accessToken, data.refreshToken);
      set({ user: data.user, status: 'authenticated', isSubmitting: false });
      return true;
    } catch (error) {
      set({
        isSubmitting: false,
        error: error instanceof Error ? error.message : 'Login failed',
      });
      return false;
    }
  },

  restoreSession: async () => {
    if (!tokenStore.getRefresh()) {
      set({ status: 'unauthenticated' });
      return;
    }

    try {
      const user = await api.get<AdminUser>('/users/me');

      if (user.role !== 'ADMIN' && user.role !== 'SUPER_ADMIN') {
        tokenStore.clear();
        set({ status: 'unauthenticated', user: null });
        return;
      }

      set({ user, status: 'authenticated' });
    } catch {
      tokenStore.clear();
      set({ status: 'unauthenticated', user: null });
    }
  },

  logout: async () => {
    try {
      await api.post('/auth/logout', {
        refreshToken: tokenStore.getRefresh(),
      });
    } catch {
      // A failed server call must not strand the user in the panel
    }

    tokenStore.clear();
    set({ user: null, status: 'unauthenticated' });
  },
}));
