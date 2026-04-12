import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Screen, AppButton } from '../../../shared';
import { useCart } from '../../cart';
import { formatCurrency } from '../../../shared/utils/formatCurrency';
import { colors } from '../../../shared/constants/colors';

export const ProductDetailsScreen = ({ route, navigation }) => {
  const { product } = route.params;
  const { addItem } = useCart();

  const handleAddToCart = () => {
    addItem({
      id: product.id,
      name: product.name,
      price: product.price,
      quantity: 1,
    });

    navigation.navigate('MainTabs', { screen: 'Cart' });
  };

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.category}>{product.category}</Text>
        <Text style={styles.name}>{product.name}</Text>
        <Text style={styles.description}>{product.description}</Text>
        <Text style={styles.price}>{formatCurrency(product.price)}</Text>

        <View style={styles.metaCard}>
          <Text style={styles.metaTitle}>Why people love it</Text>
          <Text style={styles.metaText}>
            Fast prep, reliable delivery quality, and a balanced portion for lunch
            or dinner.
          </Text>
        </View>

        <View style={styles.buttonWrap}>
          <AppButton title="Add to Cart" onPress={handleAddToCart} />
        </View>
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  buttonWrap: {
    marginTop: 24,
  },
  category: {
    color: colors.secondary,
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 8,
    textTransform: 'uppercase',
  },
  container: {
    flex: 1,
    padding: 20,
  },
  description: {
    fontSize: 16,
    color: colors.mutedText,
    marginBottom: 16,
  },
  metaCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 16,
  },
  metaText: {
    color: colors.mutedText,
    fontSize: 15,
    lineHeight: 22,
  },
  metaTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 8,
  },
  name: {
    fontSize: 28,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 10,
  },
  price: {
    fontSize: 20,
    fontWeight: '700',
    color: colors.primary,
    marginBottom: 24,
  },
});
