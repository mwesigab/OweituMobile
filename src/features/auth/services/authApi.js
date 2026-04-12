export const authApi = {
  login: async ({ email, password }) => {
    return Promise.resolve({
      user: {
        id: '1',
        name: 'Joel',
        email,
      },
      token: 'demo-token',
    });
  },
};
