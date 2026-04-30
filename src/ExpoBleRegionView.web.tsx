import * as React from 'react';

import { ExpoBleRegionViewProps } from './ExpoBleRegion.types';

export default function ExpoBleRegionView(props: ExpoBleRegionViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
