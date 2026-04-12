import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { LoadingView } from '../shared';
import { colors } from '../shared/constants/colors';
import { useAuth } from '../features/auth';
import { CheckoutScreen } from '../features/cart';
import { DeliveryAddressScreen } from '../features/delivery';
import { ProductDetailsScreen } from '../features/menu';
import { OrderTrackingScreen } from '../features/orders';
import { setupInterceptors } from '../services';
import { AuthNavigator } from './AuthNavigator';
import { MainTabs } from './MainTabs';

const Stack = createNativeStackNavigator();

export const AppNavigator = () => {
  const { isAuthenticated, hasHydrated, token } = useAuth();

  useEffect(() => {
    return setupInterceptors(() => token);
  }, [token]);

  if (!hasHydrated) {
    return (
      <View style={styles.loadingScreen}>
        <LoadingView />
      </View>
    );
  }

  return (
    <NavigationContainer>
      <Stack.Navigator>
        {!isAuthenticated ? (
          <Stack.Screen
            name="Auth"
            component={AuthNavigator}
            options={{ headerShown: false }}
          />
        ) : (
          <>
            <Stack.Screen
              name="MainTabs"
              component={MainTabs}
              options={{ headerShown: false }}
            />
            <Stack.Screen
              name="ProductDetails"
              component={ProductDetailsScreen}
              options={{ title: 'Product Details' }}
            />
            <Stack.Screen name="Checkout" component={CheckoutScreen} />
            <Stack.Screen
              name="DeliveryAddress"
              component={DeliveryAddressScreen}
              options={{ title: 'Delivery Address' }}
            />
            <Stack.Screen
              name="OrderTracking"
              component={OrderTrackingScreen}
              options={{ title: 'Track Order' }}
            />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};

const styles = StyleSheet.create({
  loadingScreen: {
    alignItems: 'center',
    backgroundColor: colors.background,
    flex: 1,
    justifyContent: 'center',
  },
});
