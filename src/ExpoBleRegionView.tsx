import { requireNativeView } from 'expo';
import * as React from 'react';

import { ExpoBleRegionViewProps } from './ExpoBleRegion.types';

const NativeView: React.ComponentType<ExpoBleRegionViewProps> =
  requireNativeView('ExpoBleRegion');

export default function ExpoBleRegionView(props: ExpoBleRegionViewProps) {
  return <NativeView {...props} />;
}
