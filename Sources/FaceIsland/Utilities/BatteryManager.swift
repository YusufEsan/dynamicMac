import Foundation
import IOKit.ps
import SwiftUI

@Observable
public final class BatteryManager {
    public static let shared = BatteryManager()
    
    public var level: Int = 100
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = false
    
    public var batteryIcon: String {
        if isCharging {
            return "battery.100percent.bolt"
        }
        switch level {
        case 0..<15:
            return "battery.0percent"
        case 15..<35:
            return "battery.25percent"
        case 35..<65:
            return "battery.50percent"
        case 65..<90:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }
    
    public var batteryColor: Color {
        if isCharging {
            return Color(red: 0.11, green: 0.84, blue: 0.38)
        }
        if level <= 20 {
            return .red
        } else if level <= 40 {
            return .yellow
        }
        return .white.opacity(0.85)
    }
    
    private var timer: Timer?
    
    private init() {
        refresh()
        startMonitoring()
    }
    
    public func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let curCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                self.level = Int((Double(curCap) / Double(maxCap)) * 100.0)
            }
            
            if let isChargingVal = desc[kIOPSIsChargingKey as String] as? Bool {
                self.isCharging = isChargingVal
            }
            
            if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                self.isPluggedIn = (state == (kIOPSACPowerValue as String))
            }
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
}
