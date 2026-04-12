import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { HomeScreen } from '../features/menu';
import { CartScreen } from '../features/cart';
import { OrdersScreen } from '../features/orders';
import { ProfileScreen } from '../features/auth';
import { useCart } from '../features/cart/hooks/useCart';
import { colors } from '../shared/constants/colors';
import { RouteErrorBoundary } from './RouteErrorBoundary';

const Tab = createBottomTabNavigator();

export const MainTabs = () => {
  const { itemCount } = useCart();

  return (
    <RouteErrorBoundary>
      <Tab.Navigator
        screenOptions={({ route }) => ({
          headerShown: true,
          tabBarActiveTintColor: colors.primary,
          tabBarInactiveTintColor: colors.mutedText,
          tabBarBadge:
            route.name === 'Cart' && itemCount ? String(itemCount) : undefined,
        })}>
        <Tab.Screen name="Home" component={HomeScreen} />
        <Tab.Screen name="Cart" component={CartScreen} />
        <Tab.Screen name="Orders" component={OrdersScreen} />
        <Tab.Screen name="Profile" component={ProfileScreen} />
      </Tab.Navigator>
    </RouteErrorBoundary>
  );
};
