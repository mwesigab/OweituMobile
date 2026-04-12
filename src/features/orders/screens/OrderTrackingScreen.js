import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Screen, LoadingView, EmptyState } from '../../../shared';
import { colors } from '../../../shared/constants/colors';
import { useOrderTracking } from '../hooks/useOrderTracking';

export const OrderTrackingScreen = ({ route }) => {
  const orderId = route.params?.order?.id;
  const { order, trackingSteps, isLoading, isError, errorMessage } =
    useOrderTracking(orderId);

  if (isLoading) {
    return (
      <Screen>
        <LoadingView />
      </Screen>
    );
  }

  if (isError || !order) {
    return (
      <Screen>
        <View style={styles.stateContainer}>
          <EmptyState title={errorMessage || 'Order not found.'} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <View style={styles.container}>
        <Text style={styles.title}>Track Order #{order.id}</Text>
        <Text style={styles.current}>Current status: {order.status}</Text>

        <View style={styles.timeline}>
          {trackingSteps.map((step) => (
            <View key={step.label} style={styles.stepRow}>
              <View
                style={[
                  styles.stepIndicator,
                  step.state === 'completed' ? styles.stepCompleted : null,
                  step.state === 'current' ? styles.stepCurrent : null,
                ]}
              />
              <Text
                style={[
                  styles.stepLabel,
                  step.state === 'current' ? styles.stepLabelCurrent : null,
                ]}>
                {step.label}
              </Text>
            </View>
          ))}
        </View>
      </View>
    </Screen>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  current: {
    color: colors.primary,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 20,
  },
  stateContainer: {
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  stepCompleted: {
    backgroundColor: colors.success,
  },
  stepCurrent: {
    backgroundColor: colors.primary,
  },
  stepIndicator: {
    backgroundColor: colors.border,
    borderRadius: 999,
    height: 14,
    marginRight: 12,
    marginTop: 3,
    width: 14,
  },
  stepLabel: {
    color: colors.text,
    fontSize: 16,
    flex: 1,
  },
  stepLabelCurrent: {
    fontWeight: '700',
  },
  stepRow: {
    flexDirection: 'row',
    marginBottom: 16,
  },
  timeline: {
    borderLeftColor: colors.border,
    borderLeftWidth: 1,
    marginLeft: 6,
    paddingLeft: 18,
  },
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
    marginBottom: 12,
  },
});
