import React, { useEffect, useState } from 'react';
import { View, Text, Button, ScrollView, StyleSheet, Platform } from 'react-native';
import * as ExpoBleRegion from 'expo-ble-region';
import * as TaskManager from 'expo-task-manager';
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';

// Set up the notification handler for the app
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: false,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});


const BACKGROUND_TASK = 'BACKGROUND_BEACON_TASK';

// Define the background task outside of the component
TaskManager.defineTask(BACKGROUND_TASK, async ({ data, error }) => {
  if (error) {
    console.error('Task Error:', error);
    return;
  }
  if (data) {
    const eventType = (data as any).eventType;
    const beacons = (data as any).beacons || [];
    const region = (data as any).region;

    console.log(`[Background Task] Event: ${eventType}`, data);

    if (eventType === 'onBeaconsDetected' && beacons.length > 0) {
      console.log(`[Background Task] Detected ${beacons.length} beacons!`);
    }

    if (eventType === 'onEnterRegion') {
      console.log(`[Background Task] Entered region: ${region}`);
      Notifications.scheduleNotificationAsync({
        content: {
          title: "Entered Region",
          body: `You have entered region ${region}`,
        },
        trigger: null,
      });
    }

    if (eventType === 'onExitRegion') {
      console.log(`[Background Task] Exited region: ${region}`);
      Notifications.scheduleNotificationAsync({
        content: {
          title: "Exited Region",
          body: `You have exited region ${region}`,
        },
        trigger: null,
      });
    }
  }
});

export default function App() {
  const [authStatus, setAuthStatus] = useState<string>('Unknown');
  const [btState, setBtState] = useState<string>('Unknown');
  const [events, setEvents] = useState<string[]>([]);
  const [isTaskRegistered, setIsTaskRegistered] = useState(false);

  // Helper to append logs to our UI
  const addEvent = (msg: string) => {
    setEvents((prev) => [msg, ...prev].slice(0, 50)); // Keep last 50
  };

  useEffect(() => {
    // Request local notification permissions on load
    Notifications.requestPermissionsAsync();

    // Check if task is already registered
    TaskManager.isTaskRegisteredAsync(BACKGROUND_TASK).then(setIsTaskRegistered);

    // Listen to module events
    const btSub = ExpoBleRegion.addListener('onBluetoothStateChanged', (event: { state: string }) => {
      setBtState(event.state);
      addEvent(`BT State: ${event.state}`);
    });

    const enterSub = ExpoBleRegion.addListener('onEnterRegion', (event: { region: string }) => {
      addEvent(`Entered Region: ${event.region}`);
      Notifications.scheduleNotificationAsync({
        content: { title: "Enter Region", body: `You have entered region ${event.region}` },
        trigger: null,
      });
    });

    const exitSub = ExpoBleRegion.addListener('onExitRegion', (event: { region: string }) => {
      addEvent(`Exited Region: ${event.region}`);
      Notifications.scheduleNotificationAsync({
        content: { title: "Exit Region", body: `You have exited region ${event.region}` },
        trigger: null,
      });
    });

    const beaconSub = ExpoBleRegion.addListener('onBeaconsDetected', (event: any) => {
      addEvent(`Beacons Detected: ${event.beacons?.length || 0}`);
    });

    const errorSub = ExpoBleRegion.addListener('onError', (event: any) => {
      addEvent(`❌ Error: ${event.error} ${event.region ? `(region: ${event.region})` : ''}`);
    });

    const debugSub = ExpoBleRegion.addListener('onDebug' as any, (event: any) => {
      addEvent(`🔍 ${event.message}`);
    });

    return () => {
      btSub.remove();
      enterSub.remove();
      exitSub.remove();
      beaconSub.remove();
      errorSub.remove();
      debugSub.remove();
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
          title="Start Scanning (Normal)"
          onPress={() => {
            ExpoBleRegion.startScanning('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', {});
            addEvent('Started Scanning (Normal)...');
          }}
        />
        <Button
          title="Start Scanning (Background Task)"
          onPress={() => {
            ExpoBleRegion.startScanningWithTask('XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX', BACKGROUND_TASK, {});
            addEvent('Started Scanning with Background Task...');
            setIsTaskRegistered(true);
          }}
        />
        <Button
          title="Stop Scanning"
          onPress={() => {
            ExpoBleRegion.stopScanning();
            addEvent('Stopped Scanning.');
          }}
        />
        <Button
          title="Stop Scanning (Task)"
          onPress={() => {
            ExpoBleRegion.stopScanningTask(BACKGROUND_TASK);
            addEvent('Stopped Scanning Task.');
            setIsTaskRegistered(false);
          }}
        />
        <Text style={styles.status}>Task Registered: {isTaskRegistered ? 'Yes' : 'No'}</Text>
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
