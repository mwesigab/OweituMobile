import React from 'react';
import { render } from '@testing-library/react-native';
import { HomeScreen } from './HomeScreen';

jest.mock('../hooks/useMenu', () => ({
  useMenu: () => ({
    products: [],
    categories: ['All'],
    searchTerm: '',
    selectedCategory: 'All',
    setSearchTerm: jest.fn(),
    setSelectedCategory: jest.fn(),
    isLoading: false,
    isError: false,
    errorMessage: '',
    refetch: jest.fn(),
  }),
}));

describe('HomeScreen', () => {
  it('renders menu title', () => {
    const navigation = { navigate: jest.fn() };
    const { getByText } = render(<HomeScreen navigation={navigation} />);
    expect(getByText('Menu')).toBeTruthy();
  });
});
