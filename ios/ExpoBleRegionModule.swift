import ExpoModulesCore
import CoreBluetooth
import CoreLocation

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

@objc
public class ExpoBleRegionTaskConsumer: NSObject, EXTaskConsumerInterface {
  public var task: EXTaskInterface?

  public func taskType() -> String {
    return "bleRegion"
  }

  public func didRegisterTask(_ task: EXTaskInterface) {
    self.task = task
    BleRegionManager.shared.taskConsumer = self
  }

  public func setOptions(_ options: [AnyHashable: Any]) { }

  public func didUnregister() {
    BleRegionManager.shared.taskConsumer = nil
  }
}

/// The BleRegionManager class handles all callbacks from CoreLocation and CoreBluetooth.
/// Because Expo Modules cannot inherit from NSObject directly, we use this separate delegate class.
@objc
public class BleRegionManager: NSObject, CLLocationManagerDelegate, CBCentralManagerDelegate {
  public static let shared = BleRegionManager()
  
  var locationManager: CLLocationManager?
  var beaconRegion: CLBeaconRegion?
  var centralManager: CBCentralManager?
  
  var taskConsumer: ExpoBleRegionTaskConsumer?
  var onEvent: ((String, [String: Any]) -> Void)?
  var isMonitoring: Bool = false
  var lastBeaconSeenTime: Date?

  /// Persisted to UserDefaults so background relaunches know the previous state
  /// and don't fire false enter/exit events.
  var lastState: CLRegionState = .unknown {
    didSet {
      UserDefaults.standard.set(lastState.rawValue, forKey: "ExpoBleRegion_lastState")
    }
  }
  
  private override init() {
    super.init()
    // Restore persisted state for background relaunch
    let saved = UserDefaults.standard.integer(forKey: "ExpoBleRegion_lastState")
    if let restored = CLRegionState(rawValue: saved) {
      lastState = restored
    }
  }
  
  private func handleStateChange(state: CLRegionState, for region: CLBeaconRegion) {
    let stateStr = state == .inside ? "inside" : state == .outside ? "outside" : "unknown"
    let lastStr = lastState == .inside ? "inside" : lastState == .outside ? "outside" : "unknown"
    onEvent?("onDebug", ["message": "state=\(stateStr) lastState=\(lastStr) region=\(region.identifier)"])

    if state == .inside && lastState != .inside {
      onEvent?("onDebug", ["message": "-> Firing onEnterRegion"])
      // Route to ONE path only to avoid duplicate notifications:
      // Foreground → JS listener (updates UI + sends notification)
      // Background → headless JS task (sends notification)
      if UIApplication.shared.applicationState == .active {
        onEvent?("onEnterRegion", ["region": region.identifier])
      } else {
        taskConsumer?.task?.execute(withData: ["eventType": "onEnterRegion", "region": region.identifier], withError: nil)
      }
      lastState = .inside
      lastBeaconSeenTime = Date()
    } else if state == .outside && lastState == .inside {
      onEvent?("onDebug", ["message": "-> Firing onExitRegion"])
      if UIApplication.shared.applicationState == .active {
        onEvent?("onExitRegion", ["region": region.identifier])
      } else {
        taskConsumer?.task?.execute(withData: ["eventType": "onExitRegion", "region": region.identifier], withError: nil)
      }
      lastState = .outside
    } else if state == .outside && lastState == .unknown {
      onEvent?("onDebug", ["message": "-> Suppressed initial outside state"])
      lastState = .outside
    } else {
      onEvent?("onDebug", ["message": "-> Ignored (duplicate state)"])
    }
  }

  /// Starts monitoring and ranging for the stored beacon region.
  /// This is the single source of truth for starting monitoring. Called either from
  /// startScanning (if already authorized) or from locationManagerDidChangeAuthorization.
  func beginMonitoring() {
    guard let region = beaconRegion else {
      onEvent?("onDebug", ["message": "beginMonitoring: no beacon region configured"])
      return
    }
    guard !isMonitoring else {
      onEvent?("onDebug", ["message": "beginMonitoring: already monitoring, skipping"])
      return
    }

    isMonitoring = true
    // NOTE: Do NOT reset lastState here. It's only reset in startScanning.
    // On background relaunch, we need to preserve the state to avoid false enter/exit.
    locationManager?.startMonitoring(for: region)
    locationManager?.requestState(for: region)
    if #available(iOS 13.0, *) {
      locationManager?.startRangingBeacons(satisfying: region.beaconIdentityConstraint)
    } else {
      locationManager?.startRangingBeacons(in: region)
    }
    onEvent?("onDebug", ["message": "beginMonitoring: started monitoring + ranging for \(region.identifier)"])
  }

  /// Cleanly stops monitoring and ranging for the current region without destroying the location manager.
  func stopCurrentMonitoring() {
    if let region = beaconRegion {
      locationManager?.stopMonitoring(for: region)
      if #available(iOS 13.0, *) {
        locationManager?.stopRangingBeacons(satisfying: region.beaconIdentityConstraint)
      } else {
        locationManager?.stopRangingBeacons(in: region)
      }
    }
    isMonitoring = false
    lastState = .unknown
    lastBeaconSeenTime = nil
    UserDefaults.standard.removeObject(forKey: "ExpoBleRegion_lastState")
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
    onEvent?("onDebug", ["message": "iOS callback: didEnterRegion"])
    if let beaconRegion = region as? CLBeaconRegion {
      handleStateChange(state: .inside, for: beaconRegion)
    }
  }

  /// Called to determine the initial state, or when requestState() is called.
  public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    let s = state == .inside ? "inside" : state == .outside ? "outside" : "unknown"
    onEvent?("onDebug", ["message": "iOS callback: didDetermineState(\(s))"])
    if let beaconRegion = region as? CLBeaconRegion {
      handleStateChange(state: state, for: beaconRegion)
    }
  }

  /// Called when the user exits the monitored iBeacon region.
  public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    onEvent?("onDebug", ["message": "iOS callback: didExitRegion"])
    if let beaconRegion = region as? CLBeaconRegion {
      handleStateChange(state: .outside, for: beaconRegion)
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

    // Ranging-based exit fallback:
    // iOS's didExitRegion is unreliable in some conditions.
    // If we're "inside" and ranging returns 0 beacons for 35+ seconds, fire exit ourselves.
    if !beacons.isEmpty {
      lastBeaconSeenTime = Date()
    } else if lastState == .inside, let lastSeen = lastBeaconSeenTime {
      let elapsed = Date().timeIntervalSince(lastSeen)
      if elapsed >= 35 {
        onEvent?("onDebug", ["message": "Ranging-based exit: no beacons for \(Int(elapsed))s, firing exit"])
        lastBeaconSeenTime = nil
        handleStateChange(state: .outside, for: region)
      }
    }
  }

  /// Called when monitoring fails for a region (e.g., too many regions, invalid UUID).
  public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    onEvent?("onError", ["error": error.localizedDescription, "region": region?.identifier ?? "unknown"])
  }

  /// Called when the location manager encounters a general error.
  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    onEvent?("onError", ["error": error.localizedDescription])
  }

  /// Called when the user's location authorization status changes (e.g., they grant permission).
  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    
    onEvent?("onDebug", ["message": "Auth changed: \(statusToString(status))"])
    
    // When permission is granted, start monitoring if we have a pending region
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      beginMonitoring()
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
    Events("onBluetoothStateChanged", "onEnterRegion", "onExitRegion", "onBeaconsDetected", "onError", "onDebug")

    // Called once when the module is created.
    OnCreate {
      BleRegionManager.shared.onEvent = { [weak self] eventName, payload in
        self?.sendEvent(eventName, payload)
      }
    }

    // Starts scanning for beacons with the provided UUID.
    Function("startScanning") { (uuidStr: String, config: [String: Any]?) in
      self.startScanning(uuidStr: uuidStr, config: config)
    }
    
    // Starts scanning and registers a task for background execution.
    AsyncFunction("startScanningWithTask") { (uuidStr: String, taskName: String, config: [String: Any]?) in
      guard let taskManager: EXTaskManagerInterface = self.appContext?.legacyModule(implementing: EXTaskManagerInterface.self) else {
        throw Exception(name: "TaskManagerUnavailable", description: "Expo task manager is unavailable.")
      }
      
      // Register task manager consumer
      taskManager.registerTask(withName: taskName, consumer: ExpoBleRegionTaskConsumer.self, options: config ?? [:])
      
      self.startScanning(uuidStr: uuidStr, config: config)
    }

    // Stops scanning and cleans up the region/location manager.
    Function("stopScanning") {
      self.stopScanning()
    }
    
    // Stops the task manager and scanning.
    AsyncFunction("stopScanningTask") { (taskName: String) in
      guard let taskManager: EXTaskManagerInterface = self.appContext?.legacyModule(implementing: EXTaskManagerInterface.self) else {
        throw Exception(name: "TaskManagerUnavailable", description: "Expo task manager is unavailable.")
      }
      if taskManager.hasRegisteredTask(withName: taskName) {
        taskManager.unregisterTask(withName: taskName, consumerClass: ExpoBleRegionTaskConsumer.self)
      }
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
    // Execute location manager setup on the main thread
    DispatchQueue.main.async {
      let manager = BleRegionManager.shared
      
      // Create location manager if needed
      if manager.locationManager == nil {
        manager.locationManager = CLLocationManager()
        manager.locationManager?.delegate = manager
      }
      
      // Configure background location if available
      if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String], backgroundModes.contains("location") {
        manager.locationManager?.allowsBackgroundLocationUpdates = true
      }
      manager.locationManager?.pausesLocationUpdatesAutomatically = false

      if let uuid = UUID(uuidString: uuidStr) {
        // IMPORTANT: Stop any existing monitoring cleanly before starting fresh.
        // Without this, iOS's monitoring state machine gets corrupted and didExitRegion won't fire.
        manager.stopCurrentMonitoring()

        // Persist UUID so AppDelegate can restore monitoring after app termination
        UserDefaults.standard.set(uuidStr, forKey: "ExpoBleRegion_lastUUID")
        let beaconConstraint = CLBeaconIdentityConstraint(uuid: uuid)
        manager.beaconRegion = CLBeaconRegion(beaconIdentityConstraint: beaconConstraint, identifier: "BeaconManagerRegion")
        manager.beaconRegion?.notifyOnEntry = true
        manager.beaconRegion?.notifyOnExit = true

        // Check current permission status
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
          status = manager.locationManager?.authorizationStatus ?? .notDetermined
        } else {
          status = CLLocationManager.authorizationStatus()
        }
        
        manager.onEvent?("onDebug", ["message": "startScanning: permission=\(statusToString(status))"])
        
        if status == .authorizedAlways || status == .authorizedWhenInUse {
          // Already authorized — start monitoring now
          manager.beginMonitoring()
        } else {
          // Not yet authorized — request permission.
          // Monitoring will start automatically in locationManagerDidChangeAuthorization
          manager.onEvent?("onDebug", ["message": "startScanning: requesting permission, monitoring will start after grant"])
          manager.locationManager?.requestAlwaysAuthorization()
        }
      }
    }
  }

  /// Stops monitoring and ranging for the active iBeacon region and cleans up managers.
  private func stopScanning() {
    DispatchQueue.main.async {
      let manager = BleRegionManager.shared
      manager.stopCurrentMonitoring()
      manager.beaconRegion = nil
      manager.locationManager = nil
      UserDefaults.standard.removeObject(forKey: "ExpoBleRegion_lastUUID")
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
    let manager = BleRegionManager.shared
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      // Reuse existing manager if available, otherwise fall back
      status = manager.locationManager?.authorizationStatus ?? CLLocationManager().authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }
    return statusToString(status)
  }
}

