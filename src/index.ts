// Reexport the native module. On web, it will be resolved to ExpoBleRegionModule.web.ts
// and on native platforms to ExpoBleRegionModule.ts
// export { default } from './ExpoBleRegionModule';
// export * from  './ExpoBleRegion.types';

import ExpoBleRegionModule from './ExpoBleRegionModule';
import { EventSubscription } from 'expo-modules-core';



export function startScanning(uuid: string, config?: Record<string, any>): void {
  ExpoBleRegionModule.startScanning(uuid, config);
}

export function stopScanning(): void {
  ExpoBleRegionModule.stopScanning();
}

export async function startScanningWithTask(uuid: string, taskName: string, config?: Record<string, any>): Promise<void> {
  await ExpoBleRegionModule.startScanningWithTask(uuid, taskName, config);
}

export async function stopScanningTask(taskName: string): Promise<void> {
  await ExpoBleRegionModule.stopScanningTask(taskName);
}

export function initializeBluetoothManager(): void {
  ExpoBleRegionModule.initializeBluetoothManager();
}

export async function requestAlwaysAuthorization(): Promise<{ status: string }> {
  return await ExpoBleRegionModule.requestAlwaysAuthorization();
}

export async function requestWhenInUseAuthorization(): Promise<{ status: string }> {
  return await ExpoBleRegionModule.requestWhenInUseAuthorization();
}

export async function getAuthorizationStatus(): Promise<string> {
  return await ExpoBleRegionModule.getAuthorizationStatus();
}

export function addListener(
  eventName: 'onBluetoothStateChanged' | 'onEnterRegion' | 'onExitRegion' | 'onBeaconsDetected' | 'onError',
  listener: (event: any) => void
): EventSubscription {
  return ExpoBleRegionModule.addListener(eventName, listener);
}

