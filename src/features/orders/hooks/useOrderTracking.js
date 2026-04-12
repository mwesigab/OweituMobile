import { useQuery } from '@tanstack/react-query';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { ordersApi } from '../services/ordersApi';

export const useOrderTracking = (orderId) => {
  const query = useQuery({
    queryKey: ['order-tracking', orderId],
    queryFn: () => ordersApi.getOrderById(orderId),
    enabled: Boolean(orderId),
    refetchInterval: 5000,
  });

  return {
    order: query.data,
    trackingSteps: query.data?.trackingSteps || [],
    isLoading: query.isLoading,
    isError: query.isError,
    errorMessage: getApiErrorMessage(
      query.error,
      'Could not refresh tracking information.'
    ),
  };
};
