import React, { useEffect, useState } from 'react';
import { View, Text, Button, ScrollView, StyleSheet } from 'react-native';
import * as ExpoBleRegion from 'expo-ble-region';
import * as TaskManager from 'expo-task-manager';

const ATTENDANCE_TASK = 'ATTENDANCE_TASK';

// Define the background task outside of the component
TaskManager.defineTask(ATTENDANCE_TASK, async ({ data, error }) => {
  if (error) {
    console.error('Task Error:', error);
    return;
  }
  if (data) {
    const eventType = (data as any).eventType;
    const beacons = (data as any).beacons || [];
    const region = (data as any).region;

    console.log(`[Background Task] Event: ${eventType}`, data);

    // Example Attendance Logic: 
    // If the event is beacons detected, and we find our specific beacon
    if (eventType === 'onBeaconsDetected' && beacons.length > 0) {
      console.log(`[Background Task] Detected ${beacons.length} beacons!`);

      // TODO: Add logic to count 3 detections (e.g. using AsyncStorage or global variable if engine stays alive)
      // Then send the HTTP request:
      // fetch('https://your-server.com/attendance', { method: 'POST', body: JSON.stringify({ event: 'clock-in', beacons }) });
    }

    if (eventType === 'onEnterRegion') {
      console.log(`[Background Task] Entered region: ${region}`);
    }

    if (eventType === 'onExitRegion') {
      console.log(`[Background Task] Exited region: ${region}`);
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
    setEvents((prev) => [msg, ...prev].slice(0, 15)); // Keep last 15
  };

  useEffect(() => {
    // Check if task is already registered
    TaskManager.isTaskRegisteredAsync(ATTENDANCE_TASK).then(setIsTaskRegistered);

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
            // Random valid UUID for testing
            ExpoBleRegion.startScanning('108535a9-78fc-4547-9de7-903bec119230', {});
            addEvent('Started Scanning (Normal)...');
          }}
        />
        <Button
          title="Start Scanning (Background Task)"
          onPress={() => {
            ExpoBleRegion.startScanningWithTask('108535a9-78fc-4547-9de7-903bec119230', ATTENDANCE_TASK, {});
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
            ExpoBleRegion.stopScanningTask(ATTENDANCE_TASK);
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
