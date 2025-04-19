// Power Management Suite - Battery Information Manager
// Copyright (C) 2025 <Your Name or Organization>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

// Original file info:
//  Battery.swift
//  app
//
//  Created by tsunami on 2025/4/1.
//

import Foundation
import SwiftUI

// Manages fetching and parsing battery and power information from system commands.
//
// This class acts as an `ObservableObject`, providing published properties
// that SwiftUI views can observe to display real-time battery and power metrics.
// It uses `ioreg` and the bundled `power_info` command-line tool to gather data.
class BatteryInfoManager: ObservableObject {
    // The current maximum capacity of the battery in mAh (AppleRawMaxCapacity).
    @Published var batteryCapacity: Int = 0
    // The original design capacity of the battery in mAh.
    @Published var designCapacity: Int = 0
    // The number of charge cycles the battery has undergone.
    @Published var cycleCount: Int = 0
    // The battery's health percentage, calculated as `(batteryCapacity / designCapacity) * 100`.
    @Published var health: Double = 0.0
    // Indicates whether the battery is currently charging.
    @Published var isCharging: Bool = false
    // The current charge percentage of the battery (CurrentCapacity).
    @Published var batteryPercent: Int = 0
    // The voltage being supplied by the power adapter in Volts.
    @Published var voltage: Double = 0.0
    // The amperage being supplied by the power adapter in Amps.
    @Published var amperage: Double = 0.0
    // The current power consumption of the entire system in Watts.
    @Published var loadwatt: Double = 0.0
    // The power being drawn from the power adapter in Watts.
    @Published var inputwatt: Double = 0.0
    // The battery's internal temperature in degrees Celsius.
    @Published var temperature: Double = 0.0
    // The current power draw from/to the battery in Watts. Positive means charging, negative means discharging.
    @Published var batteryPower: Double = 0.0
    // The current voltage of the battery in Volts.
    @Published var batteryVoltage: Double = 0.0
    // The current amperage flow from/to the battery in Amps. Positive means charging, negative means discharging.
    @Published var batteryAmperage: Double = 0.0
    // The serial number of the battery.
    @Published var serialNumber: String = "--"
    
    @Published var batteryVoltage_mV: UInt16 = 0
    @Published var batteryAmperage_mA: Int16 = 0
    
    // Initializes the manager and triggers the first battery info update.
    init() {
        updateBatteryInfo()
    }
    
    // Asynchronously fetches and updates all battery information properties.
    //
    // This function runs the `power_info` tool and `ioreg` command,
    // captures their output, and then calls `parseBatteryInfo` on the main thread
    // to update the published properties.
    func updateBatteryInfo() {
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", "ioreg -r -c AppleSmartBattery | grep -E 'DesignCapacity|CycleCount|Serial|Temperature|CurrentCapacity|AppleRawMaxCapacity' "]
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                await parseBatteryInfo(from: output)
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    @MainActor
    private func parseBatteryInfo(from output: String) {
        loadwatt = Double(getRawSystemPower())
        inputwatt = Double(getAdapterPower())
        amperage = Double(getAdapterAmperage())
        voltage = Double(getAdapterVoltage())
        batteryVoltage = Double(getBatteryVoltage())
        batteryAmperage = Double(getBatteryAmperage())
        batteryPower = Double(getBatteryPower())
        isCharging = getChargingStatus().contains("Charging")
        
        // --- Parse Temperature (ioreg - VirtualTemperature seems more reliable than power_info's) ---
        if let match = output.range(of: "\"VirtualTemperature\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            let temperatureValue = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
            temperature = Double(temperatureValue) / 100.0
        }
        
        // --- Parse Serial Number (ioreg) ---
        if let match = output.range(of: "\"Serial\" = \"([^\"]+)\"", options: .regularExpression) {
            let fullMatch = String(output[match])
            let pattern = "\"Serial\" = \"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: pattern),
               let nsMatch = regex.firstMatch(in: fullMatch, range: NSRange(fullMatch.startIndex..., in: fullMatch)),
               nsMatch.numberOfRanges > 1,
               let valueRange = Range(nsMatch.range(at: 1), in: fullMatch) {
                serialNumber = String(fullMatch[valueRange])
            }
        }
        
        // --- Parse Current Charge Percentage (ioreg) ---
        if let match = output.range(of: "\"CurrentCapacity\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            batteryPercent = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
        }
        
        // --- Parse Design Capacity (ioreg) ---
        if let match = output.range(of: "\"DesignCapacity\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            designCapacity = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
        }
        
        // --- Parse Current Max Capacity & Calculate Health (ioreg) ---
        if let match = output.range(of: "\"AppleRawMaxCapacity\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            batteryCapacity = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
            if designCapacity > 0 {
                health = (Double(batteryCapacity) / Double(designCapacity)) * 100
            }
        }
        
        // --- Parse Cycle Count (ioreg) ---
        if let match = output.range(of: "\"CycleCount\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            cycleCount = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
        }
        
    }
}
