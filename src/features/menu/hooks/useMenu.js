import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getApiErrorMessage } from '../../../shared/utils/apiError';
import { useDebounce } from '../../../shared/hooks/useDebounce';
import { menuApi } from '../services/menuApi';

const ALL_CATEGORIES = 'All';

export const useMenu = () => {
  const [selectedCategory, setSelectedCategory] = useState(ALL_CATEGORIES);
  const [searchTerm, setSearchTerm] = useState('');
  const debouncedSearchTerm = useDebounce(searchTerm, 300);
  const query = useQuery({
    queryKey: ['menu-products'],
    queryFn: menuApi.getProducts,
  });

  const categories = useMemo(() => {
    const uniqueCategories = Array.from(
      new Set((query.data || []).map((product) => product.category))
    );

    return [ALL_CATEGORIES, ...uniqueCategories];
  }, [query.data]);

  const products = useMemo(() => {
    return (query.data || []).filter((product) => {
      const matchesCategory =
        selectedCategory === ALL_CATEGORIES ||
        product.category === selectedCategory;
      const queryValue = debouncedSearchTerm.trim().toLowerCase();
      const matchesSearch =
        !queryValue ||
        product.name.toLowerCase().includes(queryValue) ||
        product.description.toLowerCase().includes(queryValue) ||
        product.category.toLowerCase().includes(queryValue);

      return matchesCategory && matchesSearch;
    });
  }, [debouncedSearchTerm, query.data, selectedCategory]);

  return {
    products,
    categories,
    searchTerm,
    selectedCategory,
    setSearchTerm,
    setSelectedCategory,
    isLoading: query.isLoading,
    isError: query.isError,
    errorMessage: getApiErrorMessage(
      query.error,
      'Could not load the menu right now.'
    ),
    refetch: query.refetch,
  };
};
