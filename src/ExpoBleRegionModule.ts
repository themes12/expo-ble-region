import { NativeModule, requireOptionalNativeModule } from 'expo-modules-core';

import { ExpoBleRegionModuleEvents } from './ExpoBleRegion.types';

declare class ExpoBleRegionModule extends NativeModule<ExpoBleRegionModuleEvents> {
  startScanning(uuid: string, config?: Record<string, any>): void;
  startScanningWithTask(uuid: string, taskName: string, config?: Record<string, any>): Promise<void>;
  stopScanning(): void;
  stopScanningTask(taskName?: string): Promise<void>;
  initializeBluetoothManager(): void;
  requestAlwaysAuthorization(): Promise<{ status: string }>;
  requestWhenInUseAuthorization(): Promise<{ status: string }>;
  getAuthorizationStatus(): Promise<string>;
}

const module = requireOptionalNativeModule<ExpoBleRegionModule>('ExpoBleRegion');

const dummyModule = {
  startScanning: () => {},
  startScanningWithTask: async () => {},
  stopScanning: () => {},
  stopScanningTask: async () => {},
  initializeBluetoothManager: () => {},
  requestAlwaysAuthorization: async () => ({ status: 'unsupported' }),
  requestWhenInUseAuthorization: async () => ({ status: 'unsupported' }),
  getAuthorizationStatus: async () => 'unsupported',
  addListener: () => ({ remove: () => {} }),
  removeListener: () => {},
  removeAllListeners: () => {},
} as unknown as ExpoBleRegionModule;

export default module ?? dummyModule;
