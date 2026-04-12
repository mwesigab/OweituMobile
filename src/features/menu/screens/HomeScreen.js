import React from 'react';
import {
  FlatList,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  View,
  Text,
} from 'react-native';
import { Screen, LoadingView, EmptyState, AppButton, AppTextInput } from '../../../shared';
import { useMenu } from '../hooks/useMenu';
import { ProductCard } from '../components/ProductCard';
import { colors } from '../../../shared/constants/colors';

export const HomeScreen = ({ navigation }) => {
  const {
    products,
    categories,
    searchTerm,
    selectedCategory,
    setSearchTerm,
    setSelectedCategory,
    isLoading,
    isError,
    errorMessage,
    refetch,
  } = useMenu();

  if (isLoading) {
    return (
      <Screen>
        <LoadingView />
      </Screen>
    );
  }

  if (isError) {
    return (
      <Screen>
        <View style={styles.stateContainer}>
          <EmptyState title={errorMessage} />
          <AppButton title="Try Again" onPress={() => refetch()} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Menu</Text>
        <Text style={styles.subtitle}>
          Fresh Ugandan favorites, quick bites, and delivery-ready drinks.
        </Text>

        <AppTextInput
          value={searchTerm}
          onChangeText={setSearchTerm}
          placeholder="Search dishes, drinks, or categories"
        />

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.categoryList}>
          {categories.map((category) => {
            const isActive = category === selectedCategory;

            return (
              <TouchableOpacity
                key={category}
                onPress={() => setSelectedCategory(category)}
                style={[styles.categoryChip, isActive ? styles.categoryChipActive : null]}
                activeOpacity={0.8}>
                <Text
                  style={[
                    styles.categoryChipLabel,
                    isActive ? styles.categoryChipLabelActive : null,
                  ]}>
                  {category}
                </Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>

        <FlatList
          data={products}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <ProductCard
              item={item}
              onPress={() =>
                navigation?.navigate('ProductDetails', { product: item })
              }
            />
          )}
          ListEmptyComponent={
            <EmptyState title="No products match your search right now." />
          }
          showsVerticalScrollIndicator={false}
        />
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  categoryChip: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 999,
    borderWidth: 1,
    marginRight: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  categoryChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  categoryChipLabel: {
    color: colors.text,
    fontSize: 14,
    fontWeight: '600',
  },
  categoryChipLabelActive: {
    color: '#FFFFFF',
  },
  categoryList: {
    paddingBottom: 16,
  },
  container: {
    flex: 1,
    padding: 16,
  },
  stateContainer: {
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  subtitle: {
    color: colors.mutedText,
    fontSize: 15,
    marginBottom: 16,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 8,
  },
});
