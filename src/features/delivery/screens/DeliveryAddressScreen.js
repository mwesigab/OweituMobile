import React, { useState } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { Screen, AppTextInput, AppButton } from '../../../shared';
import { validators, validateForm } from '../../../shared/utils/validation';
import { useDelivery } from '../hooks/useDelivery';
import { colors } from '../../../shared/constants/colors';

const validationSchema = {
  address: [validators.required('Delivery address')],
};

export const DeliveryAddressScreen = ({ navigation }) => {
  const { address: savedAddress, notes: savedNotes, saveAddress, isSaving } =
    useDelivery();
  const [address, setAddress] = useState(savedAddress);
  const [notes, setNotes] = useState(savedNotes);
  const [errors, setErrors] = useState({});

  const handleSave = async () => {
    const nextErrors = validateForm({ address }, validationSchema);
    setErrors(nextErrors);

    if (Object.keys(nextErrors).length) {
      return;
    }

    const result = await saveAddress({ address, notes });

    if (result.success) {
      Alert.alert('Saved', 'Delivery address saved.');
      navigation.goBack();
    } else {
      Alert.alert('Error', result.error || 'Could not save address.');
    }
  };

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Delivery Address</Text>
        <Text style={styles.subtitle}>
          Save a reliable drop-off point so checkout stays fast.
        </Text>

        <AppTextInput
          value={address}
          onChangeText={(value) => {
            setAddress(value);
            if (errors.address) {
              setErrors((current) => ({ ...current, address: '' }));
            }
          }}
          placeholder="Enter delivery address"
        />
        {errors.address ? (
          <Text style={styles.error}>{errors.address}</Text>
        ) : null}

        <AppTextInput
          value={notes}
          onChangeText={setNotes}
          placeholder="Additional notes"
          multiline
          numberOfLines={3}
        />

        <AppButton
          title={isSaving ? 'Saving...' : 'Save Address'}
          onPress={handleSave}
          disabled={isSaving}
        />
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  error: {
    color: colors.danger,
    fontSize: 13,
    marginBottom: 12,
    marginTop: -6,
  },
  subtitle: {
    color: colors.mutedText,
    fontSize: 15,
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: colors.text,
    marginBottom: 8,
  },
});
