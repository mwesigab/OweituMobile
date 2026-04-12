import React from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { Screen, AppButton } from '../../../shared';
import { formatCurrency } from '../../../shared/utils/formatCurrency';
import { colors } from '../../../shared/constants/colors';
import { useCart } from '../hooks/useCart';
import { useCheckout } from '../hooks/useCheckout';
import { PaymentOptionCard } from '../components/PaymentOptionCard';

export const CheckoutScreen = ({ navigation }) => {
  const { items, total } = useCart();
  const {
    paymentOptions,
    paymentMethod,
    setPaymentMethod,
    deliveryFee,
    grandTotal,
    address,
    notes,
    isPlacingOrder,
    placeOrder,
  } = useCheckout();

  const handlePlaceOrder = async () => {
    const result = await placeOrder();

    if (!result.success) {
      Alert.alert('Checkout', result.error);
      return;
    }

    Alert.alert('Success', 'Order placed successfully.');
    navigation.navigate('MainTabs', { screen: 'Orders' });
  };

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Checkout</Text>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Delivery Address</Text>
          <Text style={styles.addressText}>
            {address || 'No delivery address saved yet.'}
          </Text>
          {notes ? <Text style={styles.notesText}>Notes: {notes}</Text> : null}
          <View style={styles.secondaryButtonWrap}>
            <AppButton
              title={address ? 'Update Address' : 'Add Address'}
              onPress={() => navigation.navigate('DeliveryAddress')}
            />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Payment Options</Text>
          {paymentOptions.map((option) => (
            <PaymentOptionCard
              key={option.id}
              option={option}
              selected={option.id === paymentMethod}
              onPress={() => setPaymentMethod(option.id)}
            />
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Order Summary</Text>
          <Text style={styles.label}>Items total: {formatCurrency(total)}</Text>
          <Text style={styles.label}>
            Delivery fee: {formatCurrency(deliveryFee)}
          </Text>
          <Text style={styles.label}>Items: {items.length}</Text>
          <Text style={styles.grandTotal}>
            Grand total: {formatCurrency(grandTotal)}
          </Text>
        </View>

        <View style={styles.buttonWrap}>
          <AppButton
            title={isPlacingOrder ? 'Placing Order...' : 'Place Order'}
            onPress={handlePlaceOrder}
            disabled={isPlacingOrder}
          />
        </View>
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  addressText: {
    color: colors.text,
    fontSize: 16,
    lineHeight: 22,
  },
  buttonWrap: {
    marginTop: 8,
  },
  container: {
    flex: 1,
    padding: 20,
  },
  grandTotal: {
    color: colors.primary,
    fontSize: 18,
    fontWeight: '700',
    marginTop: 16,
  },
  label: {
    color: colors.text,
    fontSize: 16,
    marginBottom: 10,
  },
  notesText: {
    color: colors.mutedText,
    fontSize: 14,
    marginTop: 8,
  },
  secondaryButtonWrap: {
    marginTop: 16,
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '700',
    marginBottom: 12,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 20,
  },
});
