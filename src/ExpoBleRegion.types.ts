export type ExpoBleRegionModuleEvents = {
  onBluetoothStateChanged: (event: { state: string }) => void;
  onEnterRegion: (event: { region: string }) => void;
  onExitRegion: (event: { region: string }) => void;
  onBeaconsDetected: (event: {
    beacons: {
      uuid: string;
      major: number;
      minor: number;
      distance: number;
      rssi: number;
    }[];
  }) => void;
};