import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { Screen, AppButton, AppTextInput } from '../../../shared';
import { validators, validateForm } from '../../../shared/utils/validation';
import { useAuth } from '../hooks/useAuth';
import { colors } from '../../../shared/constants/colors';

const validationSchema = {
  email: [validators.required('Email'), validators.email()],
  password: [
    validators.required('Password'),
    validators.minLength(6, 'Password'),
  ],
};

export const LoginScreen = () => {
  const { signIn, isLoading } = useAuth();
  const [email, setEmail] = useState('demo@oweitu.com');
  const [password, setPassword] = useState('123456');
  const [errors, setErrors] = useState({});

  const handleLogin = async () => {
    const nextErrors = validateForm({ email, password }, validationSchema);
    setErrors(nextErrors);

    if (Object.keys(nextErrors).length) {
      return;
    }

    const result = await signIn({ email, password });

    if (!result.success) {
      Alert.alert('Login failed', result.error || 'Please try again.');
    }
  };

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Welcome Back</Text>
        <Text style={styles.subtitle}>
          Sign in to keep your orders, address, and cart synced.
        </Text>

        <Text style={styles.helper}>Use demo@oweitu.com / 123456</Text>

        <AppTextInput
          value={email}
          onChangeText={(value) => {
            setEmail(value);
            if (errors.email) {
              setErrors((current) => ({ ...current, email: '' }));
            }
          }}
          placeholder="Email"
          keyboardType="email-address"
          autoCapitalize="none"
        />
        {errors.email ? <Text style={styles.error}>{errors.email}</Text> : null}

        <AppTextInput
          value={password}
          onChangeText={(value) => {
            setPassword(value);
            if (errors.password) {
              setErrors((current) => ({ ...current, password: '' }));
            }
          }}
          placeholder="Password"
          secureTextEntry
        />
        {errors.password ? (
          <Text style={styles.error}>{errors.password}</Text>
        ) : null}

        <AppButton
          title={isLoading ? 'Signing in...' : 'Login'}
          onPress={handleLogin}
          disabled={isLoading}
        />
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    padding: 20,
  },
  error: {
    color: colors.danger,
    fontSize: 13,
    marginBottom: 12,
    marginTop: -6,
  },
  helper: {
    color: colors.mutedText,
    fontSize: 13,
    marginBottom: 16,
  },
  subtitle: {
    fontSize: 16,
    color: colors.mutedText,
    marginBottom: 8,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 8,
  },
});
