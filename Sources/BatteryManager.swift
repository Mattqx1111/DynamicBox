import Cocoa
import IOKit.ps

class BatteryManager {
    static let shared = BatteryManager()
    
    private var timer: Timer?
    private var lastPluggedIn: Bool? = nil
    
    var onChargerConnected: ((Int) -> Void)?
    var onBatteryUpdated: ((Int, Bool, Bool) -> Void)?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startMonitoring() {
        checkBattery()
        
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }
    
    func checkBattery() {
        let info = getCurrentBatteryInfo()
        
        if let last = lastPluggedIn {
            if !last && info.isPluggedIn {
                DispatchQueue.main.async {
                    self.onChargerConnected?(info.percent)
                }
            }
        }
        lastPluggedIn = info.isPluggedIn
        
        DispatchQueue.main.async {
            self.onBatteryUpdated?(info.percent, info.isCharging, info.isPluggedIn)
        }
    }
    
    func getCurrentBatteryInfo() -> (percent: Int, isCharging: Bool, isPluggedIn: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return (100, false, true)
        }
        
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 100
            let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let powerSourceState = desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
            let isPluggedIn = (powerSourceState == (kIOPSACPowerValue as String))
            let pct = maxCap > 0 ? Int((Double(current) / Double(maxCap)) * 100) : current
            return (pct, isCharging, isPluggedIn)
        }
        
        return (100, false, true)
    }
}
