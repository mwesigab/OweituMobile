const MOCK_PRODUCTS = [
  {
    id: '1',
    name: 'Rolex Special',
    category: 'Street Eats',
    price: 12000,
    description: 'Freshly made Ugandan rolex with eggs, tomatoes, and cabbage.',
  },
  {
    id: '2',
    name: 'Chicken Pilau',
    category: 'Local Favorites',
    price: 18000,
    description: 'Spiced rice with chicken, kachumbari, and house salad.',
  },
  {
    id: '3',
    name: 'Beef Burger',
    category: 'Fast Food',
    price: 22000,
    description: 'Juicy burger with fries and smoky house sauce.',
  },
  {
    id: '4',
    name: 'Tilapia Platter',
    category: 'Local Favorites',
    price: 28000,
    description: 'Pan-seared tilapia served with matooke and greens.',
  },
  {
    id: '5',
    name: 'Tropical Smoothie',
    category: 'Drinks',
    price: 9000,
    description: 'Mango, pineapple, passion fruit, and yogurt blend.',
  },
  {
    id: '6',
    name: 'Chapati Wrap',
    category: 'Street Eats',
    price: 15000,
    description: 'Grilled chicken, avocado, and spicy mayo in chapati.',
  },
];

export const menuApi = {
  getProducts: async () => {
    return Promise.resolve(MOCK_PRODUCTS);
  },
};
