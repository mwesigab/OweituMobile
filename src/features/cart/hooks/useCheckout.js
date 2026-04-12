import { useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { useDelivery } from '../../delivery/hooks/useDelivery';
import { ordersApi } from '../../orders/services/ordersApi';
import { useCart } from './useCart';

const PAYMENT_OPTIONS = [
  {
    id: 'mobile_money',
    label: 'Mobile Money',
    description: 'Pay instantly with MTN or Airtel Mobile Money.',
  },
  {
    id: 'cash_on_delivery',
    label: 'Cash on Delivery',
    description: 'Pay with cash when your order arrives.',
  },
  {
    id: 'card',
    label: 'Card',
    description: 'Pay securely with your debit or credit card.',
  },
];

const DELIVERY_FEE = 5000;

export const useCheckout = () => {
  const queryClient = useQueryClient();
  const { address, notes } = useDelivery();
  const { items, total, clearCart } = useCart();
  const [paymentMethod, setPaymentMethod] = useState(PAYMENT_OPTIONS[0].id);
  const mutation = useMutation({
    mutationFn: ordersApi.placeOrder,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders'] });
    },
  });

  const grandTotal = useMemo(() => {
    return total + DELIVERY_FEE;
  }, [total]);

  const placeOrder = async () => {
    if (!items.length) {
      return {
        success: false,
        error: 'Your cart is empty.',
      };
    }

    if (!String(address || '').trim()) {
      return {
        success: false,
        error: 'Add a delivery address before placing your order.',
      };
    }

    try {
      const order = await mutation.mutateAsync({
        items,
        subtotal: total,
        deliveryFee: DELIVERY_FEE,
        grandTotal,
        paymentMethod,
        address,
        notes,
      });

      clearCart();

      return {
        success: true,
        order,
      };
    } catch (error) {
      return {
        success: false,
        error: getApiErrorMessage(error, 'Could not place your order.'),
      };
    }
  };

  return {
    paymentOptions: PAYMENT_OPTIONS,
    paymentMethod,
    setPaymentMethod,
    deliveryFee: DELIVERY_FEE,
    grandTotal,
    address,
    notes,
    isPlacingOrder: mutation.isPending,
    placeOrder,
  };
};
