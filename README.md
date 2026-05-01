# expo-ble-region

[![npm](https://img.shields.io/npm/v/expo-ble-region)](https://www.npmjs.com/package/expo-ble-region)

> **Note:** This module currently only works with **Expo 54** (tested).

A native Expo module for iOS iBeacon region monitoring with foreground and background enter/exit events. Uses `CoreLocation` for beacon detection and integrates with Expo's `TaskManager` for headless background JavaScript execution — even when the app is terminated.

## Features

- **Foreground monitoring** — Real-time enter/exit/ranging events via JS listeners
- **Background monitoring** — Headless JS task execution via `expo-task-manager`
- **State persistence** — Survives app termination; iOS relaunches the app for region events
- **Smart event routing** — Foreground events go to JS listeners, background events go to the task consumer (no duplicate notifications)
- **Debug events** — `onDebug` event stream for real-time observability of the native state machine
- **Ranging-based exit fallback** — Detects beacon disappearance even when iOS's `didExitRegion` is delayed

## Installation

```bash
npx expo install expo-ble-region
npx expo install expo-task-manager
```

> **Note:** `expo-notifications` is **not** required by the library itself. The example app uses it to demonstrate background notifications, but you can handle enter/exit events however you like.

Add the required permissions to your `app.json`:

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Allow app to monitor beacons in the background.",
        "NSLocationWhenInUseUsageDescription": "Allow app to monitor beacons while in use.",
        "NSBluetoothAlwaysUsageDescription": "Allow app to use Bluetooth to detect beacons.",
        "UIBackgroundModes": ["location", "bluetooth-central"]
      }
    }
  }
}
```

## API

### Permissions

```typescript
import * as ExpoBleRegion from 'expo-ble-region';

// Get current authorization status
const status = await ExpoBleRegion.getAuthorizationStatus();
// Returns: 'notDetermined' | 'authorizedWhenInUse' | 'authorizedAlways' | 'denied' | 'restricted'

// Request permissions
await ExpoBleRegion.requestWhenInUseAuthorization();
await ExpoBleRegion.requestAlwaysAuthorization(); // Required for background monitoring
```

### Foreground Monitoring

Listen for beacon events while the app is open:

```typescript
import * as ExpoBleRegion from 'expo-ble-region';
import { useEffect } from 'react';

export default function App() {
  useEffect(() => {
    const enterSub = ExpoBleRegion.addListener('onEnterRegion', ({ region }) => {
      console.log('Entered region:', region);
    });

    const exitSub = ExpoBleRegion.addListener('onExitRegion', ({ region }) => {
      console.log('Exited region:', region);
    });

    const beaconSub = ExpoBleRegion.addListener('onBeaconsDetected', ({ beacons }) => {
      console.log('Beacons detected:', beacons);
    });

    const errorSub = ExpoBleRegion.addListener('onError', ({ error, region }) => {
      console.error('Error:', error, region);
    });

    return () => {
      enterSub.remove();
      exitSub.remove();
      beaconSub.remove();
      errorSub.remove();
    };
  }, []);

  const startScanning = () => {
    ExpoBleRegion.startScanning('YOUR-BEACON-UUID', {});
  };

  const stopScanning = () => {
    ExpoBleRegion.stopScanning();
  };

  // ...
}
```

### Background Monitoring

Execute JavaScript when the app is backgrounded or terminated. Define the task **outside** your React component tree:

```typescript
import * as TaskManager from 'expo-task-manager';
import * as Notifications from 'expo-notifications';
import * as ExpoBleRegion from 'expo-ble-region';

const BACKGROUND_TASK = 'BACKGROUND_BEACON_TASK';

// 1. Define the task at the top level
TaskManager.defineTask(BACKGROUND_TASK, async ({ data, error }) => {
  if (error) return;

  if (data) {
    const { eventType, region, beacons } = data as any;

    if (eventType === 'onEnterRegion') {
      await Notifications.scheduleNotificationAsync({
        content: { title: 'Entered Region', body: `Entered ${region}` },
        trigger: null,
      });
    }

    if (eventType === 'onExitRegion') {
      await Notifications.scheduleNotificationAsync({
        content: { title: 'Exited Region', body: `Exited ${region}` },
        trigger: null,
      });
    }
  }
});

// 2. Start scanning with the task
export default function App() {
  const start = async () => {
    await ExpoBleRegion.startScanningWithTask('YOUR-BEACON-UUID', BACKGROUND_TASK, {});
  };

  const stop = async () => {
    await ExpoBleRegion.stopScanningTask(BACKGROUND_TASK);
  };

  // ...
}
```

### Bluetooth State

```typescript
ExpoBleRegion.initializeBluetoothManager();

ExpoBleRegion.addListener('onBluetoothStateChanged', ({ state }) => {
  console.log('Bluetooth:', state); // 'poweredOn', 'poweredOff', etc.
});
```

### Debug Events

Stream native state machine transitions to your JS code for debugging:

```typescript
ExpoBleRegion.addListener('onDebug', ({ message }) => {
  console.log('[Debug]', message);
});
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `onEnterRegion` | `{ region: string }` | Device entered a beacon region |
| `onExitRegion` | `{ region: string }` | Device exited a beacon region |
| `onBeaconsDetected` | `{ beacons: Beacon[] }` | Ranging update (fires ~1/sec while in region) |
| `onBluetoothStateChanged` | `{ state: string }` | Bluetooth hardware state changed |
| `onError` | `{ error: string, region?: string }` | Monitoring or location error |
| `onDebug` | `{ message: string }` | Internal state machine transition |

### Beacon Object

```typescript
{
  uuid: string;
  major: number;
  minor: number;
  distance: number;  // Estimated distance in meters (-1 if unknown)
  rssi: number;      // Signal strength
}
```

## iOS Behavior Notes

- **Exit delay**: iOS intentionally delays `didExitRegion` by ~30 seconds to prevent false positives from signal bouncing. This module includes a ranging-based fallback that fires exit after 35 seconds of zero beacons.
- **Permission flow**: iOS uses a two-step permission flow. Users first grant "When In Use", then iOS later prompts to upgrade to "Always". Background monitoring requires "Always" permission.
- **App termination**: When the app is terminated, iOS continues monitoring. On a region event, iOS relaunches the app in the background and the module restores monitoring from persisted state.

## Running the Example

1. Clone the repo and install dependencies:
   ```bash
   npm install && npm run build
   cd example && npm install
   ```

2. Replace `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` in `example/App.tsx` with your beacon's UUID.

3. Build and run:

   **Local (requires Mac):**
   ```bash
   npx expo run:ios
   ```

   **EAS Build (cloud / Windows):**
   ```bash
   npx expo install eas-cli
   eas login
   eas build -p ios --profile development
   ```

> **Note:** Beacon monitoring requires a physical iPhone — simulators do not support BLE.

## Platform Support

This module is **iOS only**. Android is not supported.

## Contributing

Contributions are welcome! Please ensure any added features remain un-opinionated and delegate complex logic to `expo-task-manager`.
