import { getApiErrorMessage } from '../shared/utils/apiError';
import { api } from './api';

export const setupInterceptors = (getToken) => {
  const requestInterceptor = api.interceptors.request.use((config) => {
    const token = getToken();
    const headers = config.headers || {};

    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }

    return {
      ...config,
      headers,
    };
  });

  const responseInterceptor = api.interceptors.response.use(
    (response) => response,
    (error) => {
      const normalizedError = {
        ...error,
        message: getApiErrorMessage(error),
      };

      return Promise.reject(normalizedError);
    }
  );

  return () => {
    api.interceptors.request.eject(requestInterceptor);
    api.interceptors.response.eject(responseInterceptor);
  };
};
