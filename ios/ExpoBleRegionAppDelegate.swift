import ExpoModulesCore

public class ExpoBleRegionAppDelegate: ExpoAppDelegateSubscriber {
  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Initialize the shared manager early to receive background location events
    BleRegionManager.shared.start()
    return true
  }
}
