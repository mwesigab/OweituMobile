import React from 'react';
import {
  FlatList,
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { Screen, LoadingView, EmptyState, AppButton } from '../../../shared';
import { useOrders } from '../hooks/useOrders';
import { formatCurrency } from '../../../shared/utils/formatCurrency';
import { colors } from '../../../shared/constants/colors';

export const OrdersScreen = ({ navigation }) => {
  const { orders, isLoading, isError, errorMessage, refetch } = useOrders();

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
          <AppButton title="Reload Orders" onPress={() => refetch()} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Orders</Text>

        <FlatList
          data={orders}
          keyExtractor={(item) => item.id}
          ListEmptyComponent={<EmptyState title="No orders found." />}
          renderItem={({ item }) => (
            <TouchableOpacity
              style={styles.card}
              onPress={() => navigation.navigate('OrderTracking', { order: item })}>
              <Text style={styles.orderId}>Order #{item.id}</Text>
              <Text style={styles.status}>Status: {item.status}</Text>
              <Text style={styles.meta}>Payment: {item.paymentMethod}</Text>
              <Text style={styles.meta}>Address: {item.address}</Text>
              <Text style={styles.total}>{formatCurrency(item.total)}</Text>
            </TouchableOpacity>
          )}
        />
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#FFFFFF',
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    marginBottom: 12,
    padding: 16,
  },
  container: {
    flex: 1,
    padding: 16,
  },
  meta: {
    color: colors.mutedText,
    marginTop: 6,
  },
  orderId: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text,
  },
  stateContainer: {
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  status: {
    color: colors.mutedText,
    marginTop: 6,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 16,
  },
  total: {
    color: colors.primary,
    fontWeight: '700',
    marginTop: 8,
  },
});
