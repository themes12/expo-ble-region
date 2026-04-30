import { registerWebModule, NativeModule } from 'expo';

import { ExpoBleRegionModuleEvents } from './ExpoBleRegion.types';

class ExpoBleRegionModule extends NativeModule<ExpoBleRegionModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}

export default registerWebModule(ExpoBleRegionModule, 'ExpoBleRegionModule');
