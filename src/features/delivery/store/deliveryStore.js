import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { persistStorage } from '../../../shared/utils/persistStorage';

export const useDeliveryStore = create(
  persist(
    (set) => ({
      address: '',
      notes: '',
      setAddressDetails: ({ address, notes }) =>
        set({
          address,
          notes,
        }),
    }),
    {
      name: 'oweitu-delivery',
      storage: createJSONStorage(() => persistStorage),
    }
  )
);
