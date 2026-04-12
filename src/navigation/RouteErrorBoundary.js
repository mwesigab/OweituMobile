import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { ErrorBoundary } from 'react-error-boundary';

const Fallback = () => {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Something went wrong.</Text>
      <Text style={styles.subtitle}>Please reopen this screen.</Text>
    </View>
  );
};

export const RouteErrorBoundary = ({ children }) => {
  return <ErrorBoundary FallbackComponent={Fallback}>{children}</ErrorBoundary>;
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: '#666',
    textAlign: 'center',
  },
});
