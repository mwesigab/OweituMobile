import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Screen, AppButton } from '../../../shared';
import { useAuth } from '../hooks/useAuth';
import { colors } from '../../../shared/constants/colors';

export const ProfileScreen = () => {
  const navigation = useNavigation();
  const { user, signOut } = useAuth();

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Profile</Text>
        <View style={styles.card}>
          <Text style={styles.label}>Name</Text>
          <Text style={styles.value}>{user?.name || 'Guest'}</Text>

          <Text style={styles.label}>Email</Text>
          <Text style={styles.value}>{user?.email || '-'}</Text>
        </View>

        <View style={styles.buttonWrap}>
          <AppButton
            title="Manage Delivery Address"
            onPress={() => navigation.navigate('DeliveryAddress')}
          />
        </View>

        <View style={styles.buttonWrap}>
          <AppButton title="Logout" onPress={signOut} />
        </View>
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  buttonWrap: {
    marginTop: 16,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 16,
  },
  container: {
    flex: 1,
    padding: 20,
  },
  label: {
    color: colors.mutedText,
    fontSize: 13,
    marginBottom: 4,
    marginTop: 12,
    textTransform: 'uppercase',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 20,
  },
  value: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '600',
  },
});
