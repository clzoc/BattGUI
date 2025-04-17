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

/// Manages fetching and parsing battery and power information from system commands.
///
/// This class acts as an `ObservableObject`, providing published properties
/// that SwiftUI views can observe to display real-time battery and power metrics.
/// It uses `ioreg` and the bundled `power_info` command-line tool to gather data.
class BatteryInfoManager: ObservableObject {
    /// The current maximum capacity of the battery in mAh (AppleRawMaxCapacity).
    @Published var batteryCapacity: Int = 0
    /// The original design capacity of the battery in mAh.
    @Published var designCapacity: Int = 0
    /// The number of charge cycles the battery has undergone.
    @Published var cycleCount: Int = 0
    /// The battery's health percentage, calculated as `(batteryCapacity / designCapacity) * 100`.
    @Published var health: Double = 0.0
    /// Indicates whether the battery is currently charging.
    @Published var isCharging: Bool = false
    /// The current charge percentage of the battery (CurrentCapacity).
    @Published var batteryPercent: Int = 0
    /// The voltage being supplied by the power adapter in Volts.
    @Published var voltage: Double = 0.0
    /// The amperage being supplied by the power adapter in Amps.
    @Published var amperage: Double = 0.0
    /// The current power consumption of the entire system in Watts.
    @Published var loadwatt: Double = 0.0
    /// The power being drawn from the power adapter in Watts.
    @Published var inputwatt: Double = 0.0
    /// The battery's internal temperature in degrees Celsius.
    @Published var temperature: Double = 0.0
    /// The current power draw from/to the battery in Watts. Positive means charging, negative means discharging.
    @Published var batteryPower: Double = 0.0
    /// The current voltage of the battery in Volts.
    @Published var batteryVoltage: Double = 0.0
    /// The current amperage flow from/to the battery in Amps. Positive means charging, negative means discharging.
    @Published var batteryAmperage: Double = 0.0
    /// The serial number of the battery.
    @Published var serialNumber: String = "--"
    
    /// Initializes the manager and triggers the first battery info update.
    init() {
        updateBatteryInfo()
    }
    
    /// Asynchronously fetches and updates all battery information properties.
    ///
    /// This function runs the `power_info` tool and `ioreg` command,
    /// captures their output, and then calls `parseBatteryInfo` on the main thread
    /// to update the published properties.
    func updateBatteryInfo() {
        Task {
            guard let power_info_URL = Bundle.main.url(forResource: "power_info", withExtension: nil) else {
                // TODO: Replace fatalError with more robust error handling (e.g., logging, showing alert)
                fatalError("Executable 'power_info' not found in bundle.")
            }
            
            let po = Process()
            po.executableURL = URL(fileURLWithPath: "/bin/zsh")
            po.arguments = ["-c", "source ~/.zshrc; \(power_info_URL.path)"]
            let pp = Pipe()
            po.standardOutput = pp
            po.standardError = pp
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", "ioreg -r -c AppleSmartBattery | grep -E 'DesignCapacity|CycleCount|Serial|Temperature|CurrentCapacity|AppleRawMaxCapacity' "]
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try po.run()
                po.waitUntilExit()
                let dt = pp.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: dt, encoding: .utf8) ?? ""
                
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                output += String(data: data, encoding: .utf8) ?? ""

                await parseBatteryInfo(from: output)
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    /// Parses the combined output from `power_info` and `ioreg` to update the battery properties.
    ///
    /// This function uses regular expressions to extract specific values from the command output string.
    /// It must be called on the main actor because it updates `@Published` properties.
    ///
    /// - Parameter output: The combined string output from the system commands.
    @MainActor
    private func parseBatteryInfo(from output: String) {
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
        // --- Parse Charging Status (power_info) ---
        if let match = output.range(of: "battery_status=([a-zA-Z]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "Idle"
            isCharging = valueStr.contains("Charging")
        }
        // --- Parse Current Charge Percentage (ioreg) ---
        if let match = output.range(of: "\"CurrentCapacity\" = ([0-9]+)", options: .regularExpression) {
            let valueStr = String(output[match]).components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "0"
            batteryPercent = Int(valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))) ?? 0
        }
        // --- Parse Adapter Voltage (power_info) ---
        let patternV = "adapter_voltage=([0-9]+(?:\\.[0-9]+)?)V"
        if let regex = try? NSRegularExpression(pattern: patternV) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                voltage = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse Adapter Amperage (power_info) ---
        let patternA = "adapter_amperage=([0-9]+(?:\\.[0-9]+)?)A"
        if let regex = try? NSRegularExpression(pattern: patternA) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                amperage = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse System Power (power_info) ---
        let patternSysP = "sys_power=([0-9]+(?:\\.[0-9]+)?)W"
        if let regex = try? NSRegularExpression(pattern: patternSysP) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                loadwatt = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse Adapter Power (power_info) ---
        let patternAdpP = "adapter_power=([0-9]+(?:\\.[0-9]+)?)W"
        if let regex = try? NSRegularExpression(pattern: patternAdpP) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                inputwatt = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse Battery Power (power_info) ---
        let patternBattP = "battery_power=(\\-?[0-9]+(?:\\.[0-9]+)?)W" // Allow negative
        if let regex = try? NSRegularExpression(pattern: patternBattP) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                batteryPower = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse Battery Voltage (power_info) ---
        let patternBattV = "battery_voltage=([0-9]+(?:\\.[0-9]+)?)V"
        if let regex = try? NSRegularExpression(pattern: patternBattV) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                batteryVoltage = Double(valueStr) ?? 0.0
            }
        }
        // --- Parse Battery Amperage (power_info) ---
        let patternBattA = "battery_amperage=(\\-?[0-9]+(?:\\.[0-9]+)?)A" // Allow negative
        if let regex = try? NSRegularExpression(pattern: patternBattA) {
            let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
            if let match = matches.first, let range = Range(match.range(at: 1), in: output) {
                let valueStr = String(output[range])
                batteryAmperage = Double(valueStr) ?? 0.0
            }
        }

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
    }
}
