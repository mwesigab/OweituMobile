import { useQuery } from '@tanstack/react-query';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { ordersApi } from '../services/ordersApi';

export const useOrders = () => {
  const query = useQuery({
    queryKey: ['orders'],
    queryFn: ordersApi.getOrders,
  });

  return {
    orders: query.data || [],
    isLoading: query.isLoading,
    isError: query.isError,
    errorMessage: getApiErrorMessage(
      query.error,
      'Could not load your orders right now.'
    ),
    refetch: query.refetch,
  };
};
