import React from 'react';
import {
  FlatList,
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { Screen, AppButton, EmptyState } from '../../../shared';
import { useCart } from '../hooks/useCart';
import { formatCurrency } from '../../../shared/utils/formatCurrency';
import { colors } from '../../../shared/constants/colors';

export const CartScreen = ({ navigation }) => {
  const { items, total, removeItem } = useCart();

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Cart</Text>

        <FlatList
          data={items}
          keyExtractor={(item) => item.id}
          ListEmptyComponent={<EmptyState title="Your cart is empty." />}
          renderItem={({ item }) => (
            <View style={styles.row}>
              <View style={styles.rowContent}>
                <Text style={styles.name}>{item.name}</Text>
                <Text style={styles.meta}>
                  {item.quantity} x {formatCurrency(item.price)}
                </Text>
              </View>

              <TouchableOpacity onPress={() => removeItem(item.id)}>
                <Text style={styles.remove}>Remove</Text>
              </TouchableOpacity>
            </View>
          )}
          contentContainerStyle={items.length ? null : styles.emptyList}
        />

        <View style={styles.footer}>
          <Text style={styles.total}>Total: {formatCurrency(total)}</Text>
          <AppButton
            title="Proceed to Checkout"
            onPress={() => navigation.navigate('Checkout')}
            disabled={!items.length}
          />
        </View>
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
  },
  emptyList: {
    flexGrow: 1,
    justifyContent: 'center',
  },
  footer: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingTop: 16,
  },
  meta: {
    marginTop: 4,
    color: colors.mutedText,
  },
  name: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text,
  },
  remove: {
    color: colors.danger,
    fontWeight: '700',
  },
  row: {
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 14,
  },
  rowContent: {
    flex: 1,
    marginRight: 12,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 16,
  },
  total: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 12,
    color: colors.text,
  },
});
