import { useState } from 'react';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { useDeliveryStore } from '../store/deliveryStore';
import { deliveryApi } from '../services/deliveryApi';

export const useDelivery = () => {
  const { address, notes, setAddressDetails } = useDeliveryStore();
  const [isSaving, setIsSaving] = useState(false);

  const saveAddress = async (payload) => {
    setIsSaving(true);

    try {
      const savedAddress = await deliveryApi.saveAddress(payload);
      setAddressDetails(savedAddress);
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: getApiErrorMessage(error, 'Could not save delivery address.'),
      };
    } finally {
      setIsSaving(false);
    }
  };

  return {
    address,
    notes,
    isSaving,
    saveAddress,
  };
};
