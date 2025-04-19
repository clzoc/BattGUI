// Power Management Suite - Main Content View
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
//
//  ContentView.swift
//  app
//
//  Created by tsunami on 2025/3/22.
//

import SwiftUI
import AppKit

struct ContentView: View {
    // State for battery info and UI controls
    @StateObject private var batteryManager = BatteryInfoManager()
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var num: Float = 70
    @State private var iconwidth: CGFloat = 15
    @State private var debounceTask: Task<Void, Never>?

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    var body: some View {
        // Restore original VStack structure
        VStack(alignment: .leading, spacing: 0, content: {
            VStack(alignment: .center, spacing: 0) {
                HStack(alignment: .center, spacing: 0, content: {
                    HStack(spacing: 0) {
                        // Localized Text and flexible frame
                        Text(LocalizedStringKey("limit.label")).font(.system(size: 13)).bold()
                        Text(String(format: "%.0f", num)).font(.system(size: 13)).frame(width: 17, alignment: .trailing)
                        Text("%").font(.system(size: 13))
                    }.frame(minWidth: 70, idealWidth: 90, maxWidth: .infinity, minHeight: 30).background( // Use minWidth
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThickMaterial) // Changed to transparent
                    ).padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Button(action: {}) {
                        HStack {
                            // Localized Text and flexible frame
                            Text(LocalizedStringKey("enable.power.button")).font(.system(size: 13)).bold()
                        }.frame(minWidth: 70, idealWidth: 90, maxWidth: .infinity, minHeight: 30).background( // Use minWidth
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThickMaterial) // Changed to transparent
                        )
                    }.padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)).buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: { quitApp() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .imageScale(.large)
                                .foregroundColor(.black)
                        }.frame(width: 30, height: 30).background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.ultraThickMaterial) // Changed to transparent
                        )
                    }.padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 10)).buttonStyle(PlainButtonStyle())
                })
                
                Slider(value: $num, in: 10...99, onEditingChanged: {editing in
                    if !editing {
                        debounceTask?.cancel()
                        debounceTask = Task.detached(priority: .medium) {
                            try? await Task.sleep(nanoseconds: 000_000_000) // 500ms
                            //guard let battURL = Bundle.main.url(forResource: "batt", withExtension: nil) else {
                            //    // Localized fatalError
                            //    fatalError(NSLocalizedString("executable.not.found.error", comment: "Error when batt executable is missing"))
                            //}
                            let pr = Process()
                            //pr.launchPath = "/usr/bin/osascript"
                            //pr.arguments = ["-e", "do shell script \"source ~/.zshrc; sudo batt install --allow-non-root-access\" with prompt "安装 daemon 辅助程序需要授权" with administrator privileges"]
                            pr.executableURL = URL(fileURLWithPath: "/bin/zsh")
                            //pr.arguments = ["-c", "source ~/.zshrc; \(battURL.path)
                            //pr.arguments = ["-c", "source ~/.zshrc; \(battURL.path) limit \(await Int(num))"]
                            pr.arguments = ["-c", "source ~/.zshrc; curl -Lv --unix-socket /var/run/batt.sock -XPUT http://localhost/limit --data \(await Int(num))"]
                            let pi = Pipe()
                            pr.standardOutput = pi
                            pr.standardError = pi
                            
                            do {
                                try pr.run()
                                pr.waitUntilExit()
                                let dt = pi.fileHandleForReading.readDataToEndOfFile()
                                let re = String(data: dt, encoding: .utf8) ?? ""
                                if let _ = extractSet(from: re) {
                                    //print(sn)
                                } else {
                                    // Localized print
                                    print(NSLocalizedString("cannot.set.charge.limit.error", comment: "Error message when setting charge limit fails"))
                                }
                                
                            } catch {
                                // Localized print with formatting
                                print(String(format: NSLocalizedString("execution.failed.error", comment: "Generic execution failure message"), error.localizedDescription))
                            }
                        }
                    }
                })
                .padding(EdgeInsets(top: 10, leading: 10, bottom: 5, trailing: 10)) // Added bottom padding

                // --- Power Flow Visualization ---
                PowerFlowView(
                    inputPower: batteryManager.inputwatt,
                    batteryPower: batteryManager.batteryPower,
                    systemLoad: batteryManager.loadwatt
                )
                .frame(minWidth: 300)
                .padding(EdgeInsets(top: 5, leading: 10, bottom: 0, trailing: 10))
                .animation(.easeIn, value: batteryManager.batteryPower)
                // --- End Power Flow Visualization ---
            }
            
            Divider().padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
            VStack(alignment: .leading, content: {
                HStack(alignment: .center, content: {
                    Image(systemName: Icons.designcapacity).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("design.capacity.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text("\(batteryManager.designCapacity) mAh").font(.system(size: 13))
                    Text("100%").font(.system(size: 13)).frame(width: 40, alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.serial).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("serial.number.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(batteryManager.serialNumber).font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
            })
            
            Divider().padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
            VStack(alignment: .leading, content: {
                HStack(alignment: .center, content: {
                    Image(systemName: Icons.maxcapacity).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("max.capacity.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text("\(batteryManager.batteryCapacity) mAh").font(.system(size: 13))
                    Text(String(format: "%.0f%%", batteryManager.health)).font(.system(size: 13)).frame(width: 40, alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(alignment: .center, content: {
                    Image(systemName: Icons.cyclecount).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("cycle.count.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text("\(batteryManager.cycleCount)").font(.system(size: 13)).frame(width: 40, alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.flame).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("battery.temperature.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.temperature) + " °C").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.levelcapacity).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("battery.level.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%d%%", batteryManager.batteryPercent)).font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
            })
            
            Divider().padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
            VStack(alignment: .leading, content: {
                HStack(content: {
                    Image(systemName: Icons.charge).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("charging.status.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    // Localized Yes/No
                    Text(batteryManager.isCharging ? LocalizedStringKey("yes") : LocalizedStringKey("no")).font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.iconLight).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("battery.power.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.batteryPower) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.normLight).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("battery.amperage.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.3f", batteryManager.batteryAmperage) + " A").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.slash).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("battery.voltage.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.batteryVoltage) + " V").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
            })
            
            Divider().padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
            VStack(alignment: .leading, content: {
                HStack(content: {
                    Image(systemName: Icons.iconLight).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("system.load.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.loadwatt) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.iconLight).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("adapter.input.power.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.inputwatt) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.normLight).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("adapter.input.amperage.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.3f", batteryManager.amperage) + " A").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 1, trailing: 15))
                HStack(content: {
                    Image(systemName: Icons.slash).frame(width: iconwidth, alignment: .center)
                    Text(LocalizedStringKey("adapter.input.voltage.label")).font(.system(size: 13)).bold() // Localized
                    Spacer()
                    Text(String(format: "%.2f", batteryManager.voltage) + " V").font(.system(size: 13)).frame(alignment: .trailing)
                }).padding(EdgeInsets(top: 0, leading: 15, bottom: 10, trailing: 15))
            })
        })
        // Restore .onReceive here
        .onReceive(timer) { _ in
             batteryManager.updateBatteryInfo()
        }
    }

    }

func extractGet(from input: String) -> Int? {
    let pattern = #"Upper limit:\s+(\d+)%"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    
    let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
    
    guard let match = regex.firstMatch(in: input, options: [], range: nsRange),
          let valueRange = Range(match.range(at: 1), in: input) else {
        return nil
    }
    
    return Int(input[valueRange])
}

func extractSet(from input: String) -> Int? {
    let pattern = #"charging limit to\s+(\d+)%"#
    
    // 创建正则表达式，因为确定模式有效，所以使用 try!
    let regex = try! NSRegularExpression(pattern: pattern)
    
    let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
    
    // 使用可选绑定而不是强制解包
    if let match = regex.firstMatch(in: input, options: [], range: nsRange),
       let valueRange = Range(match.range(at: 1), in: input),
       let value = Int(input[valueRange]) {
        return value
    }
    
    // 如果没有匹配或无法转换为整数，返回 nil
    return nil
}

extension ContentView {
    // 定义图标常量
    struct Icons {
        static let normLight = "minus.plus.batteryblock"
        static let normDark = "minus.plus.batteryblock.fill"
        static let stopLight = "minus.plus.batteryblock.slash"
        static let stopDark = "minus.plus.batteryblock.slash.fill"
        static let excepLight = "minus.plus.batteryblock.exclamationmark"
        static let excepDark = "minus.plus.batteryblock.exclamationmark.fill"
        static let iconLight = "bolt.batteryblock"
        static let iconDark = "bolt.batteryblock.fill"
        static let slash = "minus.plus.and.fluid.batteryblock"
        static let serial = "note.text"
        static let flame = "flame"
        static let designcapacity = "battery.100percent"
        static let levelcapacity = "battery.50percent"
        static let maxcapacity = "percent"
        static let cyclecount = "clock.arrow.trianglehead.counterclockwise.rotate.90"
        static let charge = "powerplug"
    }
}

//#Preview {
//    ContentView()
//}
