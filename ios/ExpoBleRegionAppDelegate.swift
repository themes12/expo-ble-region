import ExpoModulesCore
import CoreLocation

public class ExpoBleRegionAppDelegate: ExpoAppDelegateSubscriber {
  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // If the app was relaunched by iOS due to a region event (e.g., beacon exit while terminated),
    // restore the CLLocationManager delegate so we can receive the pending callbacks.
    if launchOptions?[.location] != nil {
      let manager = BleRegionManager.shared
      if manager.locationManager == nil {
        manager.locationManager = CLLocationManager()
        manager.locationManager?.delegate = manager
      }

      // Restore the last monitored beacon region so background events can be processed
      if let uuidString = UserDefaults.standard.string(forKey: "ExpoBleRegion_lastUUID") {
        if let uuid = UUID(uuidString: uuidString) {
          let constraint = CLBeaconIdentityConstraint(uuid: uuid)
          manager.beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: "BeaconManagerRegion")
          manager.beaconRegion?.notifyOnEntry = true
          manager.beaconRegion?.notifyOnExit = true
          manager.beginMonitoring()
        }
      }
    }
    return true
  }
}
