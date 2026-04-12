const STATUS_FLOW = [
  'Order received',
  'Preparing',
  'Out for delivery',
  'Delivered',
];

const STATUS_WINDOWS = [0, 15000, 30000, 45000];

let mockOrders = [
  {
    id: '1001',
    status: 'Preparing',
    total: 35000,
    subtotal: 30000,
    deliveryFee: 5000,
    paymentMethod: 'Mobile Money',
    address: 'Kiwatule, Kampala',
    notes: 'Call on arrival',
    items: [
      { id: '2', name: 'Chicken Pilau', quantity: 1, price: 18000 },
      { id: '5', name: 'Tropical Smoothie', quantity: 1, price: 9000 },
    ],
    createdAt: new Date(Date.now() - 20000).toISOString(),
  },
];

const getStepIndex = (createdAt) => {
  const elapsed = Date.now() - new Date(createdAt).getTime();
  let currentIndex = 0;

  STATUS_WINDOWS.forEach((windowStart, index) => {
    if (elapsed >= windowStart) {
      currentIndex = index;
    }
  });

  return Math.min(currentIndex, STATUS_FLOW.length - 1);
};

const hydrateOrder = (order) => {
  const currentIndex = getStepIndex(order.createdAt);
  const status = STATUS_FLOW[currentIndex];

  return {
    ...order,
    status,
    trackingSteps: STATUS_FLOW.map((step, index) => ({
      label: step,
      state:
        index < currentIndex
          ? 'completed'
          : index === currentIndex
            ? 'current'
            : 'upcoming',
    })),
  };
};

export const ordersApi = {
  getOrderById: async (orderId) => {
    const order = mockOrders.find((item) => item.id === orderId);
    return Promise.resolve(order ? hydrateOrder(order) : null);
  },
  getOrders: async () => {
    return Promise.resolve(mockOrders.map(hydrateOrder));
  },
  placeOrder: async (payload) => {
    const order = {
      id: `${1000 + mockOrders.length + 1}`,
      status: 'Order received',
      total: payload.grandTotal,
      subtotal: payload.subtotal,
      deliveryFee: payload.deliveryFee,
      paymentMethod: payload.paymentMethod,
      address: payload.address,
      notes: payload.notes,
      items: payload.items,
      createdAt: new Date().toISOString(),
    };

    mockOrders = [order, ...mockOrders];

    return Promise.resolve(hydrateOrder(order));
  },
};
