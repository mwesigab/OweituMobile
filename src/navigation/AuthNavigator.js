import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { LoginScreen } from '../features/auth';
import { RouteErrorBoundary } from './RouteErrorBoundary';

const Stack = createNativeStackNavigator();

export const AuthNavigator = () => {
  return (
    <RouteErrorBoundary>
      <Stack.Navigator>
        <Stack.Screen
          name="Login"
          component={LoginScreen}
          options={{ title: 'Login' }}
        />
      </Stack.Navigator>
    </RouteErrorBoundary>
  );
};
