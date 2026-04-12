import React from 'react';
import { View, TextInput, StyleSheet } from 'react-native';
import { colors } from '../constants/colors';

export const AppTextInput = ({
  value,
  onChangeText,
  placeholder,
  secureTextEntry,
  ...props
}) => {
  return (
    <View style={styles.container}>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        secureTextEntry={secureTextEntry}
        style={styles.input}
        placeholderTextColor={colors.mutedText}
        {...props}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 10,
    marginBottom: 12,
    backgroundColor: '#FFFFFF',
  },
  input: {
    paddingHorizontal: 14,
    paddingVertical: 14,
    fontSize: 16,
    color: colors.text,
  },
});
