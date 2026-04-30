import ExpoModulesCore
import CoreBluetooth
import CoreLocation
import UserNotifications

/// Helper method to convert geolocation permission status to a string representation.
private func statusToString(_ status: CLAuthorizationStatus) -> String {
  switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedAlways: return "authorizedAlways"
    case .authorizedWhenInUse: return "authorizedWhenInUse"
    @unknown default: return "unknown"
  }
}

/// The BleRegionManager class handles all callbacks from CoreLocation and CoreBluetooth.
/// Because Expo Modules cannot inherit from NSObject directly, we use this separate delegate class.
@objc
public class BleRegionManager: NSObject, CLLocationManagerDelegate, CBCentralManagerDelegate, UNUserNotificationCenterDelegate {
  public static let shared = BleRegionManager()
  
  var locationManager: CLLocationManager?
  var beaconRegion: CLBeaconRegion?
  var centralManager: CBCentralManager?
  
  var onEvent: ((String, [String: Any]) -> Void)?
  
  private override init() {
    super.init()
  }
  
  func start() {
    DispatchQueue.main.async {
      if self.locationManager == nil {
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
      }
    }
    UNUserNotificationCenter.current().delegate = self
  }

  /// Triggers a local notification with a specific title and body.
  func sendLocalNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  /// Ensures notifications show up even when the app is in the foreground
  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  /// Called whenever the Bluetooth hardware state changes (e.g., turned on, turned off).
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    var msg = ""
    switch central.state {
      case .unknown: msg = "unknown"
      case .resetting: msg = "resetting"
      case .unsupported: msg = "unsupported"
      case .unauthorized: msg = "unauthorized"
      case .poweredOff: msg = "poweredOff"
      case .poweredOn: msg = "poweredOn"
      @unknown default: msg = "unknown"
    }
    onEvent?("onBluetoothStateChanged", ["state": msg])
  }

  /// Called when the user enters the monitored iBeacon region.
  public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if let beaconRegion = region as? CLBeaconRegion {
      sendLocalNotification(title: "Region Event", body: "Entered region: \(region.identifier)")
      onEvent?("onEnterRegion", ["region": beaconRegion.identifier])
    }
  }

  /// Called to determine the initial state, or when requestState() is called.
  public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    if let beaconRegion = region as? CLBeaconRegion {
      if state == .inside {
        onEvent?("onEnterRegion", ["region": beaconRegion.identifier])
      } else if state == .outside {
        onEvent?("onExitRegion", ["region": beaconRegion.identifier])
      }
    }
  }

  /// Called when the user exits the monitored iBeacon region.
  public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if let beaconRegion = region as? CLBeaconRegion {
      sendLocalNotification(title: "Region Event", body: "Exit region: \(region.identifier)")
      onEvent?("onExitRegion", ["region": beaconRegion.identifier])
    }
  }

  /// Called continuously while inside a beacon region to provide distance and signal strength updates.
  public func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
    let beaconArray = beacons.map { beacon -> [String: Any] in
      return [
        "uuid": beacon.uuid.uuidString,
        "major": beacon.major.intValue,
        "minor": beacon.minor.intValue,
        "distance": beacon.accuracy,
        "rssi": beacon.rssi
      ]
    }
    onEvent?("onBeaconsDetected", ["beacons": beaconArray])
  }

  /// Called when the user's location authorization status changes (e.g., they grant permission).
  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      if let beaconRegion = self.beaconRegion {
        self.locationManager?.startMonitoring(for: beaconRegion)
        self.locationManager?.requestState(for: beaconRegion)
        if #available(iOS 13.0, *) {
          self.locationManager?.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        } else {
          self.locationManager?.startRangingBeacons(in: beaconRegion)
        }
      }
    }
  }
}

/// The main Expo Module class exposed to React Native.
public class ExpoBleRegionModule: Module {

  /// This is the required Expo Modules definition block.
  /// It defines the name of the module, the events it can send, and registers the JS-callable functions.
  public func definition() -> ModuleDefinition {
    // Sets the name of the module that JavaScript code will use to refer to the module.
    Name("ExpoBleRegion")

    // Declare the events that this module can send to JS.
    Events("onBluetoothStateChanged", "onEnterRegion", "onExitRegion", "onBeaconsDetected")

    // Called once when the module is created.
    OnCreate {
      BleRegionManager.shared.onEvent = { [weak self] eventName, payload in
        self?.sendEvent(eventName, payload)
      }
    }

    // A simple test function.
    Function("hello") {
      return "Hello world! 👋"
    }

    // Triggers a local iOS push notification.
    Function("sendLocalNotification") { (title: String, body: String) in
      BleRegionManager.shared.sendLocalNotification(title: title, body: body)
    }

    // Starts scanning for beacons with the provided UUID.
    Function("startScanning") { (uuidStr: String, config: [String: Any]?) in
      self.startScanning(uuidStr: uuidStr, config: config)
    }

    // Stops scanning and cleans up the region/location manager.
    Function("stopScanning") {
      self.stopScanning()
    }

    // Initializes the Bluetooth central manager to begin receiving bluetooth state events.
    Function("initializeBluetoothManager") {
      self.initializeBluetoothManager()
    }

    // Prompts the user for "Always" location permissions.
    AsyncFunction("requestAlwaysAuthorization") { () -> [String: String] in
      return self.requestAlwaysAuthorization()
    }

    // Prompts the user for "When In Use" location permissions.
    AsyncFunction("requestWhenInUseAuthorization") { () -> [String: String] in
      return self.requestWhenInUseAuthorization()
    }

    // Gets the current authorization status without prompting the user.
    AsyncFunction("getAuthorizationStatus") { () -> String in
      return self.getAuthorizationStatus()
    }
  }

  // MARK: - Extracted Methods

  /// Starts monitoring and ranging for an iBeacon region using the given UUID.
  private func startScanning(uuidStr: String, config: [String: Any]?) {
    // Request permission to send local notifications
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      if granted {
        print("Notifications allowed")
      } else {
        print("Notifications not allowed")
      }
    }

    // Execute location manager setup on the main thread
    DispatchQueue.main.async {
      let manager = BleRegionManager.shared
      
      if manager.locationManager == nil {
          manager.locationManager = CLLocationManager()
          manager.locationManager?.delegate = manager
      }
      
      manager.locationManager?.requestAlwaysAuthorization()
      
      // Only allow background location updates if the developer actually added 'location' to UIBackgroundModes in Info.plist.
      // If we don't check this, the app will instantly crash with an NSInternalInconsistencyException!
      if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], backgroundModes.contains("location") {
        manager.locationManager?.allowsBackgroundLocationUpdates = true
      }
      manager.locationManager?.pausesLocationUpdatesAutomatically = false

      if let uuid = UUID(uuidString: uuidStr) {
        let beaconConstraint = CLBeaconIdentityConstraint(uuid: uuid)
        manager.beaconRegion = CLBeaconRegion(beaconIdentityConstraint: beaconConstraint, identifier: "BeaconManagerRegion")
        manager.beaconRegion?.notifyOnEntry = true
        manager.beaconRegion?.notifyOnExit = true

        if let region = manager.beaconRegion {
          manager.locationManager?.startMonitoring(for: region)
          manager.locationManager?.requestState(for: region) // <--- Fetches the initial state immediately!
          if #available(iOS 13.0, *) {
            manager.locationManager?.startRangingBeacons(satisfying: region.beaconIdentityConstraint)
          } else {
            manager.locationManager?.startRangingBeacons(in: region)
          }
        }
      }
    }
  }

  /// Stops monitoring and ranging for the active iBeacon region and cleans up managers.
  private func stopScanning() {
    let manager = BleRegionManager.shared
    if let beaconRegion = manager.beaconRegion {
      manager.locationManager?.stopMonitoring(for: beaconRegion)
      if #available(iOS 13.0, *) {
        manager.locationManager?.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
      } else {
        manager.locationManager?.stopRangingBeacons(in: beaconRegion)
      }
      manager.beaconRegion = nil
      manager.locationManager = nil
    }
  }

  /// Initializes the Bluetooth Central Manager, which immediately triggers a state update callback.
  private func initializeBluetoothManager() {
    BleRegionManager.shared.centralManager = CBCentralManager(delegate: BleRegionManager.shared, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
  }

  /// Requests permanent (background) location access from the user.
  private func requestAlwaysAuthorization() -> [String: String] {
    let manager = BleRegionManager.shared
    if manager.locationManager == nil {
      manager.locationManager = CLLocationManager()
      manager.locationManager?.delegate = manager
    }
    manager.locationManager?.requestAlwaysAuthorization()
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.locationManager?.authorizationStatus ?? .notDetermined
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    return ["status": statusToString(status)]
  }

  /// Requests foreground location access from the user.
  private func requestWhenInUseAuthorization() -> [String: String] {
    let manager = BleRegionManager.shared
    if manager.locationManager == nil {
      manager.locationManager = CLLocationManager()
      manager.locationManager?.delegate = manager
    }
    manager.locationManager?.requestWhenInUseAuthorization()
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.locationManager?.authorizationStatus ?? .notDetermined
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    return ["status": statusToString(status)]
  }

  /// Retrieves the current location authorization status without prompting the user.
  private func getAuthorizationStatus() -> String {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      let tempManager = CLLocationManager()
      status = tempManager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    return statusToString(status)
  }
}

