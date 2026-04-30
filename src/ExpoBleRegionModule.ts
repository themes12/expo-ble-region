import { NativeModule, requireNativeModule } from 'expo-modules-core';

import { ExpoBleRegionModuleEvents } from './ExpoBleRegion.types';

declare class ExpoBleRegionModule extends NativeModule<ExpoBleRegionModuleEvents> {
  startScanning(uuid: string, config?: Record<string, any>): void;
  startScanningWithTask(uuid: string, taskName: string, config?: Record<string, any>): void;
  stopScanning(): void;
  stopScanningTask(taskName?: string): void;
  initializeBluetoothManager(): void;
  requestAlwaysAuthorization(): Promise<{ status: string }>;
  requestWhenInUseAuthorization(): Promise<{ status: string }>;
  getAuthorizationStatus(): Promise<string>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<ExpoBleRegionModule>('ExpoBleRegion');
