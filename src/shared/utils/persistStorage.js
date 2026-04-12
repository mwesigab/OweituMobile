import AsyncStorage from '@react-native-async-storage/async-storage';

export const persistStorage = {
  getItem: async (name) => {
    return AsyncStorage.getItem(name);
  },
  setItem: async (name, value) => {
    return AsyncStorage.setItem(name, value);
  },
  removeItem: async (name) => {
    return AsyncStorage.removeItem(name);
  },
};
