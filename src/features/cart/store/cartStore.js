import { create } from 'zustand';

export const useCartStore = create((set) => ({
  items: [],
  addItem: (item) =>
    set((state) => {
      const existing = state.items.find((x) => x.id === item.id);

      if (existing) {
        return {
          items: state.items.map((x) =>
            x.id === item.id
              ? { ...x, quantity: x.quantity + item.quantity }
              : x
          ),
        };
      }

      return {
        items: [...state.items, item],
      };
    }),
  removeItem: (id) =>
    set((state) => ({
      items: state.items.filter((x) => x.id !== id),
    })),
  clearCart: () => set({ items: [] }),
}));
