# expo-ble-region

A native Expo module for iOS that enables BLE beacon region monitoring (iBeacon) with background enter/exit events. This module uses iOS's `CoreLocation` and integrates beautifully with Expo's `TaskManager` to ensure background JavaScript execution even when the app is completely killed.

## Installation

```bash
npx expo install expo-ble-region
npx expo install expo-task-manager # Required for background execution
```

Add the appropriate permissions to your app's configuration (`app.json`):
```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Allow app to monitor your location in the background.",
        "NSLocationWhenInUseUsageDescription": "Allow app to monitor your location while using.",
        "NSBluetoothAlwaysUsageDescription": "Allow app to use Bluetooth to detect beacons.",
        "UIBackgroundModes": ["location", "bluetooth-central"]
      }
    }
  }
}
```

## API Usage

### 1. Requesting Permissions
Before monitoring regions, you must request the necessary Bluetooth and Location permissions.

```typescript
import * as ExpoBleRegion from 'expo-ble-region';

// Get current authorization status
const status = await ExpoBleRegion.getAuthorizationStatus(); // Returns 'authorizedAlways', 'denied', etc.

// Request 'When in Use' permissions
await ExpoBleRegion.requestWhenInUseAuthorization();

// Request 'Always' permissions (Required for background tracking)
await ExpoBleRegion.requestAlwaysAuthorization();
```

### 2. Foreground Monitoring
If you only need to detect beacons while your app is open, you can simply add listeners to the module events.

```typescript
import * as ExpoBleRegion from 'expo-ble-region';
import { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    // Fired when entering a beacon region
    const enterSub = ExpoBleRegion.addListener('onEnterRegion', ({ region }) => {
      console.log('Entered region:', region);
    });

    // Fired when exiting a beacon region
    const exitSub = ExpoBleRegion.addListener('onExitRegion', ({ region }) => {
      console.log('Exited region:', region);
    });

    // Fired continuously while ranging beacons inside the region
    const beaconSub = ExpoBleRegion.addListener('onBeaconsDetected', ({ beacons }) => {
      console.log('Beacons detected:', beacons);
    });

    return () => {
      enterSub.remove();
      exitSub.remove();
      beaconSub.remove();
    };
  }, []);

  const startScanning = () => {
    // Provide your beacon's UUID
    ExpoBleRegion.startScanning('YOUR-UUID-HERE', {});
  };

  const stopScanning = () => {
    ExpoBleRegion.stopScanning();
  };
  
  // ...
}
```

### 3. Background Task Manager (App Killed/Background)
If you want to track attendance or run logic while the app is killed, use `TaskManager`.

**Note:** The Task Manager must be defined outside your React component tree.

```typescript
import * as TaskManager from 'expo-task-manager';
import * as ExpoBleRegion from 'expo-ble-region';

const ATTENDANCE_TASK = 'ATTENDANCE_TASK';

// 1. Define the task outside of your UI components
TaskManager.defineTask(ATTENDANCE_TASK, async ({ data, error }) => {
  if (error) {
    console.error('Task Error:', error);
    return;
  }
  
  if (data) {
    const eventType = (data as any).eventType; // 'onEnterRegion' | 'onExitRegion' | 'onBeaconsDetected'
    const beacons = (data as any).beacons || [];
    
    // Write your background logic here (e.g., HTTP POST requests)
    if (eventType === 'onBeaconsDetected' && beacons.length > 0) {
      console.log(`Detected ${beacons.length} beacons in background!`);
    }
  }
});

// 2. Start scanning and link it to the task
export default function App() {
  const startBackgroundScanning = () => {
    // Provide the UUID and your Task Name
    ExpoBleRegion.startScanningWithTask('YOUR-UUID-HERE', ATTENDANCE_TASK, {});
  };

  const stopBackgroundScanning = () => {
    ExpoBleRegion.stopScanningTask(ATTENDANCE_TASK);
  };
  
  // ...
}
```

### 4. Utilities

#### `initializeBluetoothManager(): void`
Initializes the iOS `CBCentralManager` which enables the `onBluetoothStateChanged` event listener.
```typescript
ExpoBleRegion.initializeBluetoothManager();

ExpoBleRegion.addListener('onBluetoothStateChanged', ({ state }) => {
  console.log('Bluetooth state:', state); // 'poweredOn', 'poweredOff', etc.
});
```



Contributions are welcome! Please ensure that any added features remain un-opinionated and delegate complex JavaScript execution to `expo-task-manager`.
