import { useState } from 'react';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { useAuthStore } from '../store/authStore';
import { authApi } from '../services/authApi';

export const useAuth = () => {
  const { user, token, isAuthenticated, login, logout, hasHydrated } =
    useAuthStore();
  const [isLoading, setIsLoading] = useState(false);

  const signIn = async ({ email, password }) => {
    setIsLoading(true);

    try {
      const response = await authApi.login({ email, password });
      login(response);
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: getApiErrorMessage(error, 'Login failed. Please try again.'),
      };
    } finally {
      setIsLoading(false);
    }
  };

  return {
    user,
    token,
    isAuthenticated,
    hasHydrated,
    isLoading,
    signIn,
    signOut: logout,
  };
};
