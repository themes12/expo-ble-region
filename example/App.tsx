import React, { useEffect, useState } from 'react';
import { View, Text, Button, ScrollView, StyleSheet } from 'react-native';
import * as ExpoBleRegion from 'expo-ble-region';

export default function App() {
  const [authStatus, setAuthStatus] = useState<string>('Unknown');
  const [btState, setBtState] = useState<string>('Unknown');
  const [events, setEvents] = useState<string[]>([]);

  // Helper to append logs to our UI
  const addEvent = (msg: string) => {
    setEvents((prev) => [msg, ...prev].slice(0, 15)); // Keep last 15
  };

  useEffect(() => {
    // Listen to module events
    const btSub = ExpoBleRegion.addListener('onBluetoothStateChanged', (event: { state: string }) => {
      setBtState(event.state);
      addEvent(`BT State: ${event.state}`);
    });

    const enterSub = ExpoBleRegion.addListener('onEnterRegion', (event: { region: string }) => {
      addEvent(`Entered Region: ${event.region}`);
      // ExpoBleRegion.sendLocalNotification('Enter Region', `You have entered region ${event.region}`);
    });

    const exitSub = ExpoBleRegion.addListener('onExitRegion', (event: { region: string }) => {
      addEvent(`Exited Region: ${event.region}`);
      // ExpoBleRegion.sendLocalNotification('Exit Region', `You have exited region ${event.region}`);
    });

    const beaconSub = ExpoBleRegion.addListener('onBeaconsDetected', (event: any) => {
      addEvent(`Beacons Detected: ${event.beacons?.length || 0}`);
    });

    return () => {
      btSub.remove();
      enterSub.remove();
      exitSub.remove();
      beaconSub.remove();
    };
  }, []);

  const handleGetAuthStatus = async () => {
    const status = await ExpoBleRegion.getAuthorizationStatus();
    setAuthStatus(status);
  };

  const handleRequestAlways = async () => {
    const response = await ExpoBleRegion.requestAlwaysAuthorization();
    setAuthStatus(response?.status || 'Unknown');
  };

  const handleRequestWhenInUse = async () => {
    const response = await ExpoBleRegion.requestWhenInUseAuthorization();
    setAuthStatus(response?.status || 'Unknown');
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.header}>ExpoBleRegion Tester</Text>
      <Text style={styles.subtitle}>Test Hello: {ExpoBleRegion.hello()}</Text>

      <View style={styles.section}>
        <Text style={styles.title}>Location Permissions</Text>
        <Text style={styles.status}>Current Status: {authStatus}</Text>
        <Button title="Get Status" onPress={handleGetAuthStatus} />
        <Button title="Request 'Always'" onPress={handleRequestAlways} />
        <Button title="Request 'When In Use'" onPress={handleRequestWhenInUse} />
      </View>

      <View style={styles.section}>
        <Text style={styles.title}>Bluetooth Management</Text>
        <Text style={styles.status}>Current State: {btState}</Text>
        <Button title="Initialize Bluetooth" onPress={() => ExpoBleRegion.initializeBluetoothManager()} />
      </View>

      <View style={styles.section}>
        <Text style={styles.title}>Beacon Scanning</Text>
        <Button
          title="Start Scanning (Test UUID)"
          onPress={() => {
            // Random valid UUID for testing
            ExpoBleRegion.startScanning('108535a9-78fc-4547-9de7-903bec119230', {});
            addEvent('Started Scanning...');
          }}
        />
        <Button
          title="Stop Scanning"
          onPress={() => {
            ExpoBleRegion.stopScanning();
            addEvent('Stopped Scanning.');
          }}
        />
      </View>

      <View style={styles.section}>
        <Text style={styles.title}>Local Notifications</Text>
        <Button
          title="Send Test Notification"
          onPress={() => ExpoBleRegion.sendLocalNotification('Test Title', 'This is a test notification from JS')}
        />
      </View>

      <View style={[styles.section, { flex: 1 }]}>
        <Text style={styles.title}>Event Logs</Text>
        <Button title="Clear Logs" onPress={() => setEvents([])} color="#888" />
        <View style={styles.logBox}>
          {events.length === 0 && <Text style={styles.logText}>No events yet...</Text>}
          {events.map((e, i) => (
            <Text key={i} style={styles.logText}>
              • {e}
            </Text>
          ))}
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: 60,
    paddingHorizontal: 20,
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  header: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 20,
  },
  section: {
    width: '100%',
    marginVertical: 10,
    padding: 15,
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#eee',
  },
  title: {
    fontWeight: '700',
    fontSize: 16,
    marginBottom: 10,
    textAlign: 'center',
  },
  status: {
    textAlign: 'center',
    marginBottom: 10,
    color: '#0066cc',
    fontWeight: '600',
  },
  logBox: {
    marginTop: 10,
    padding: 10,
    backgroundColor: '#000',
    borderRadius: 8,
    minHeight: 100,
  },
  logText: {
    color: '#0f0',
    fontSize: 12,
    fontFamily: 'monospace',
    marginVertical: 2,
  },
});
