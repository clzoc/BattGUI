// Power Management Suite - Power Flow Visualization View
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

import SwiftUI
/// A `PreferenceKey` used to measure and report the width of the middle flow section
/// in the `PowerFlowView`. This allows the animation width to adapt dynamically.
struct WidthPreferenceKey: PreferenceKey {
    /// The default width value.
    static var defaultValue: CGFloat = 0
    /// Combines multiple reported width values, using the maximum.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // Use the maximum width reported, in case of multiple reports (though unlikely here)
        value = max(value, nextValue())
    }
}

/// A SwiftUI `View` that visualizes the flow of power between the power adapter,
/// the battery, and the system load (laptop).
///
/// It displays icons for each component and uses animated, shaped connectors
/// to represent the direction and magnitude of power flow.
struct PowerFlowView: View {
    /// The power currently being supplied by the adapter in Watts.
    let inputPower: Double
    /// The power flowing into (+) or out of (-) the battery in Watts.
    let batteryPower: Double
    /// The power currently being consumed by the system in Watts.
    let systemLoad: Double

    // MARK: - Configuration Constants
    /// The size of the icons used (power plug, battery, laptop).
    private let iconSize: CGFloat = 15
    /// The standard height of the flow connector sections.
    private let flowHeight: CGFloat = 40
    /// The spacing between the main view components (icons and flow).
    private let spacing: CGFloat = 5
    /// The corner radius used for the squircle shapes.
    private let cornerRadius: CGFloat = 12

    // MARK: - Color Constants (Currently Unused - Consider Applying)
    /// Color intended for battery charging flow.
    private let batteryChargeColor: Color = .green
    /// Color intended for battery discharging flow.
    private let batteryDischargeColor: Color = .orange
    /// Color intended for system load flow.
    private let systemLoadColor: Color = .red
 
    // MARK: - State Variables
    /// The measured width of the middle flow section, used for animations. Updated via `WidthPreferenceKey`.
    @State private var middleSectionWidth: CGFloat = 10 // Default non-zero width
    
    /// State flag to control the animation highlight on the charging-related icons/flows.
    @State private var animateCharge = false
    /// State flag to control the animation highlight on the load-related icons/flows.
    @State private var animateLoad = false
    /// State variable controlling the animated width of the flow gradient.
    @State private var animateFlowWidth: CGFloat = 0
    /// State variable controlling the color of the animated flow gradient.
    @State private var animateFlowColor = Color.yellow.opacity(0.8)
    /// Timer responsible for driving the repeating flow animation cycle.
    @State private var animationTimer: Timer? = nil
    
    /// The main body of the power flow visualization view.
    var body: some View {
        HStack(spacing: spacing) {
            VStack(alignment: .leading, spacing: flowHeight, content: {
                if inputPower > 0.01 {
                    ZStack {
                        // corners: [TL, TR, BR, BL]
                        generateSquircle(width: iconSize + 20, height: batteryPower > 0 ? flowHeight * 1.5 : flowHeight, radius: cornerRadius, corners: [true, false, false, true])
                            .fill(.ultraThickMaterial)
                        Image(systemName: "powerplug.portrait")
                            .font(.system(size: iconSize))
                            .foregroundColor(animateCharge ? Color.yellow : Color.black)
                            .offset(x: 1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: batteryPower > 0 ? flowHeight * 1.5 : flowHeight) // Apply frame to the ZStack, conditional height
                }
                
                if batteryPower < 0 {
                    ZStack {
                        // corners: [TL, TR, BR, BL]
                        generateSquircle(width: iconSize + 20, height: flowHeight, radius: cornerRadius, corners: [true, false, false, true])
                            .fill(.ultraThickMaterial)
                        Image(systemName: batteryPower > 0 ? "battery.100.bolt" : (batteryPower < 0 ? "battery.75" : "battery.100")) // Simple icon logic
                            .font(.system(size: iconSize))
                            .foregroundColor(animateCharge ? Color.orange : Color.black)
                            .offset(x: 1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: flowHeight) // Apply frame to the ZStack
                }
            })
            
            // Middle Flow Section - Measure width using PreferenceKey
            Group {
                if inputPower > 0.01 {
                    if batteryPower == 0 {
                        ZStack {
                            ZStack(alignment: .leading, content: {
                                Rectangle()
                                    .fill(.ultraThickMaterial)
                                    .frame(height: flowHeight)
                                    .background(GeometryReader { geometry in
                                        Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
                                    })
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .blur(radius: 1.5)
                                    .offset(x: 0)
                                    .frame(width: animateFlowWidth, height: flowHeight)
                            })
                            Text(String(format: "%.2f", inputPower) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                        }
                    } else if batteryPower > 0 {
                        VStack(alignment: .center, spacing: 0) {
                            ZStack {
                                ZStack(alignment: .leading, content: {
                                    Rectangle()
                                        .fill(.ultraThickMaterial)
                                        .frame(width: middleSectionWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight * 0.75, endLength: flowHeight, direction: 1)
                                        )
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .blur(radius: 1.5)
                                        .offset(x: 0)
                                        .frame(width: animateFlowWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight * 0.75, endLength: flowHeight, direction: 1)
                                        )
                                })
                                Text(String(format: "%.2f", batteryPower) + " W").font(.system(size: 13)).frame(alignment: .trailing)

                            }
                            
                            ZStack {
                                ZStack(alignment: .leading, content: {
                                    Rectangle()
                                        .fill(.ultraThickMaterial)
                                        .frame(width: middleSectionWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight * 0.75, endLength: flowHeight, direction: 0)
                                        )
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .blur(radius: 1.5)
                                        .offset(x: 0)
                                        .frame(width: animateFlowWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight * 0.75, endLength: flowHeight, direction: 0)
                                        )
                                })
                                Text(String(format: "%.2f", systemLoad) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                            }
                        }
//                        .background(GeometryReader { geometry in
//                            Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
//                        })
                    } else { // batteryPower < 0
                        // Similar pattern for negative battery power
                        VStack(alignment: .center, spacing: 0) {
                            ZStack {
                                ZStack(alignment: .leading, content: {
                                    Rectangle()
                                        .fill(.ultraThickMaterial)
                                        .frame(width: middleSectionWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight, endLength: flowHeight * 0.75, direction: 0)
                                        )
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .blur(radius: 1.5)
                                        .offset(x: 0)
                                        .frame(width: animateFlowWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight, endLength: flowHeight * 0.75, direction: 0)
                                        )
                                })
                                Text(String(format: "%.2f", inputPower) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                            }
                            
                            ZStack {
                                ZStack(alignment: .leading, content: {
                                    Rectangle()
                                        .fill(.ultraThickMaterial)
                                        .frame(width: middleSectionWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight, endLength: flowHeight * 0.75, direction: 1)
                                        )
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .blur(radius: 1.5)
                                        .offset(x: 0)
                                        .frame(width: animateFlowWidth, height: flowHeight * 1.5)
                                        .clipShape(
                                            flowShape(width: middleSectionWidth, height: flowHeight * 1.5,
                                                      startLength: flowHeight, endLength: flowHeight * 0.75, direction: 1)
                                        )
                                })
                                Text(String(format: "%.2f", batteryPower * -1) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                            }
                        }
//                        .background(GeometryReader { geometry in
//                            Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
//                        })
                    }
                } else {
                    ZStack {
                        ZStack(alignment: .leading, content: {
                            Rectangle()
                                .fill(.ultraThickMaterial)
                                .frame(height: flowHeight)
                                .background(GeometryReader { geometry in
                                    Color.clear.preference(key: WidthPreferenceKey.self, value: geometry.size.width)
                                })
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.clear, animateFlowColor]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .blur(radius: 1.5)
                                .offset(x: 0)
                                .frame(width: animateFlowWidth, height: flowHeight)
                        })
                        Text(String(format: "%.2f", batteryPower * -1) + " W").font(.system(size: 13)).frame(alignment: .trailing)
                    }
                }
            }
            
            VStack(alignment: .trailing, spacing: flowHeight, content: {
                // Battery Icon (conditional)
                if batteryPower > 0 {
                    ZStack {
                        // corners: [TL, TR, BR, BL]
                        generateSquircle(width: iconSize + 20, height: flowHeight, radius: cornerRadius, corners: [false, true, true, false])
                            .fill(.ultraThickMaterial)
                        
                        Image(systemName: batteryPower > 0 ? "battery.100.bolt" : (batteryPower < 0 ? "battery.75" : "battery.100")) // Simple icon logic
                            .font(.system(size: iconSize))
                            .foregroundColor(animateLoad ? Color.green : Color.black)
                            .offset(x: -1, y: 0)
                    }
                    .frame(width: iconSize + 20, height: flowHeight) // Apply frame to the ZStack
                }
                
                // System Load Icon (Laptop)
                ZStack {
                    // corners: [TL, TR, BR, BL]
                    generateSquircle(width: iconSize + 20, height: (batteryPower < 0 && inputPower > 0.01) ? flowHeight * 1.5 : flowHeight, radius: cornerRadius, corners: [false, true, true, false])
                        .fill(.ultraThickMaterial)
                    
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: iconSize))
                        .foregroundColor(animateLoad ? Color.blue : Color.black)
                        .offset(x: -1, y: 0)
                }
                .frame(width: iconSize + 20, height: (batteryPower < 0 && inputPower > 0.01) ? flowHeight * 1.5 : flowHeight) // Apply frame to the ZStack
            }).frame(width: iconSize + 20)
            
        }
        // Replace the problematic onAppear block with this macOS-compatible version
        .onAppear {
            // Force width calculation on initial appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Use the available space if not already set
                if middleSectionWidth <= 10 {
                    // Use NSScreen instead of UIScreen for macOS
                    let screenWidth = NSScreen.main?.frame.width ?? 800 // Default fallback
                    // Estimate the parent width (adjust multiplier as needed)
                    let parentWidth = screenWidth * 0.4 - ((iconSize + 20) * 2) - (spacing * 2)
                    middleSectionWidth = max(parentWidth, 50) // Ensure minimum width
                }
            }
            
            DispatchQueue.main.async {
                animateFlowWidth = 0
                animateFlowColor = Color.yellow.opacity(0.8)
                withAnimation(.easeOut(duration: 1.0)) {
                    animateCharge = true
                    animateLoad = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 1.0)) {
                        animateCharge = false
                    }
                    withAnimation(.linear(duration: 1.0)) {
                        animateFlowWidth = middleSectionWidth / 2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            animateFlowColor = Color.blue.opacity(0.8)
                        }
                        withAnimation(.linear(duration: 1.0)) {
                            animateFlowWidth = middleSectionWidth
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Only toggle if the timer hasn't been invalidated yet
                        withAnimation(.easeOut(duration: 1.0)) {
                            animateFlowColor = Color.clear
                            animateLoad = true
                        }
                    }
                }
            }
            
            // Create a repeating animation cycle with no delay between expansions
            animationTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                // Immediately start the next expansion animation
                DispatchQueue.main.async {
                    animateFlowWidth = 0
                    animateFlowColor = Color.yellow.opacity(0.8)
                    withAnimation(.easeOut(duration: 1.0)) {
                        animateCharge = true
                        animateLoad = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeIn(duration: 1.0)) {
                            animateCharge = false
                        }
                        withAnimation(.linear(duration: 1.0)) {
                            animateFlowWidth = middleSectionWidth / 2
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                animateFlowColor = Color.blue.opacity(0.8)
                            }
                            withAnimation(.linear(duration: 1.0)) {
                                animateFlowWidth = middleSectionWidth
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Only toggle if the timer hasn't been invalidated yet
                            withAnimation(.easeOut(duration: 1.0)) {
                                animateFlowColor = Color.clear
                                animateLoad = true
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            animationTimer?.invalidate()
            animationTimer = nil
        }
        // Keep the existing onPreferenceChange
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            if width > 10 { // Avoid updating with very small values
                self.middleSectionWidth = width
            }
        }
    }
}

// DocC comments for generateSquircle are already present. Skipping this block.
func generateSquircle(width: CGFloat, height: CGFloat, radius: CGFloat, corners: [Bool]) -> Path {
    precondition(corners.count == 4, "Corners array must contain exactly 4 boolean values (TL, TR, BR, BL)")
    var path = Path() // Changed from NSBezierPath

    // --- Constants defining the reference squircle shape ---
    // These likely represent control point offsets for a reference radius
    let f5: CGFloat = 63.0000 // Outer edge offset?
    let f4: CGFloat = 36.7519 // Control point offset?
    let f3: CGFloat = 23.6278 // Control point offset?
    let f2: CGFloat = 14.4275 // Endpoint offset?
    let f1: CGFloat = 6.6844  // Endpoint offset?
    let f0: CGFloat = 0.0     // Origin/Zero offset

    // Constants for the middle curve segment's control points
    let a0: CGFloat = 11.457
    let a1: CGFloat = 8.843

    let refRadius: CGFloat = 35 // The radius for which the above constants were defined
        
    // --- Scale constants based on desired radius ---
    let ratio: CGFloat = radius / refRadius // Avoid division by zero if radius is 0? Consider max(radius, 0.001) / refRadius
    
    let s0 = f0 * ratio
    let s1 = f1 * ratio
    let s2 = f2 * ratio
    let s3 = f3 * ratio
    let s4 = f4 * ratio
    let s5 = f5 * ratio
    
    let s6 = a0 * ratio // Scaled a0
    let s7 = a1 * ratio // Scaled a1
    
    // --- Calculate coordinates relative to width/height ---
    // 's' prefix usually means relative to origin (0,0)
    // 'w' prefix means relative to width (x-axis)
    // 'h' prefix means relative to height (y-axis)
    let w0 = width - s0
    let w1 = width - s1
    let w2 = width - s2
    let w3 = width - s3
    let w4 = width - s4
    let w5 = width - s5
    let w6 = width - s6 // width - scaled a0
    let w7 = width - s7 // width - scaled a1
    
    let h0 = height - s0
    let h1 = height - s1
    let h2 = height - s2
    let h3 = height - s3
    let h4 = height - s4
    let h5 = height - s5
    let h6 = height - s6 // height - scaled a0
    let h7 = height - s7 // height - scaled a1
    
    // --- Construct the Path ---
    // Start at bottom-left edge, just above the corner
    path.move(to: CGPoint(x: s0, y: s5)) // Changed from NSPoint
    
    let tl = corners[0]
    let tr = corners[1]
    let br = corners[2]
    let bl = corners[3]
    if bl {
        // Bottom-left corner (3 curves)
        path.addCurve(to: CGPoint(x: s1, y: s2), control1: CGPoint(x: s0, y: s4), control2: CGPoint(x: s0, y: s3)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: s2, y: s1), control1: CGPoint(x: s7, y: s6), control2: CGPoint(x: s6, y: s7)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: s5, y: s0), control1: CGPoint(x: s3, y: s0), control2: CGPoint(x: s4, y: s0)) // Changed from NSPoint & path.curve
    } else {
        path.addLine(to: CGPoint(x: s0, y: s0))
        path.addLine(to: CGPoint(x: s5, y: s0))
    }
    
    // Bottom edge
    path.addLine(to: CGPoint(x: w5, y: s0)) // Changed from NSPoint & path.line

    if br {
        // Bottom-right corner (3 curves)
        path.addCurve(to: CGPoint(x: w2, y: s1), control1: CGPoint(x: w4, y: s0), control2: CGPoint(x: w3, y: s0)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: w1, y: s2), control1: CGPoint(x: w6, y: s7), control2: CGPoint(x: w7, y: s6)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: w0, y: s5), control1: CGPoint(x: w0, y: s3), control2: CGPoint(x: w0, y: s4)) // Changed from NSPoint & path.curve
    } else {
        path.addLine(to: CGPoint(x: w0, y: s0))
        path.addLine(to: CGPoint(x: w0, y: s5))
    }

    // Right edge
    path.addLine(to: CGPoint(x: w0, y: h5)) // Changed from NSPoint & path.line

    if tr {
        // Top-right corner (3 curves)
        path.addCurve(to: CGPoint(x: w1, y: h2), control1: CGPoint(x: w0, y: h4), control2: CGPoint(x: w0, y: h3)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: w2, y: h1), control1: CGPoint(x: w7, y: h6), control2: CGPoint(x: w6, y: h7)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: w5, y: h0), control1: CGPoint(x: w3, y: h0), control2: CGPoint(x: w4, y: h0)) // Changed from NSPoint & path.curve
    } else {
        path.addLine(to: CGPoint(x: w0, y: h0))
        path.addLine(to: CGPoint(x: w5, y: h0))
    }

    // Top edge
    path.addLine(to: CGPoint(x: s5, y: h0)) // Changed from NSPoint & path.line

    if tl {
        // Top-left corner (3 curves)
        path.addCurve(to: CGPoint(x: s2, y: h1), control1: CGPoint(x: s4, y: h0), control2: CGPoint(x: s3, y: h0)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: s1, y: h2), control1: CGPoint(x: s6, y: h7), control2: CGPoint(x: s7, y: h6)) // Changed from NSPoint & path.curve
        path.addCurve(to: CGPoint(x: s0, y: h5), control1: CGPoint(x: s0, y: h3), control2: CGPoint(x: s0, y: h4)) // Changed from NSPoint & path.curve
    } else {
        path.addLine(to: CGPoint(x: s0, y: h0))
        path.addLine(to: CGPoint(x: s0, y: h5))
    }

    path.closeSubpath() // Changed from path.close()
    return path
}

/// Creates a custom `Path` shape used for the flowing connectors between power components.
///
/// This shape resembles a trapezoid with curved top and bottom edges, allowing it to smoothly
/// connect sections of potentially different heights.
///
/// - Parameters:
///   - width: The width of the flow shape.
///   - height: The total height of the flow shape.
///   - startLength: The height of the vertical edge on the starting side (left).
///   - endLength: The height of the vertical edge on the ending side (right).
///   - direction: Determines the orientation of the curves. `0` for top curve, `1` for bottom curve.
/// - Returns: A `Path` representing the flow connector shape.
func flowShape(width: CGFloat, height: CGFloat, startLength: CGFloat, endLength: CGFloat, direction: Int) -> Path {
    var path = Path()
    if direction == 0 { // Top curve connects (0,0) to (width, height - endLength)
        path.move(to: CGPoint(x: 0, y: 0))
        let controlPoint1_x: CGFloat = width * 0.3 // Adjust control points for smoother curve
        let controlPoint1_y: CGFloat = 0
        let controlPoint2_x: CGFloat = width * 0.7
        let controlPoint2_y: CGFloat = height - endLength
        path.addCurve(to: CGPoint(x: width, y: height - endLength), control1: CGPoint(x: controlPoint1_x, y: controlPoint1_y), control2: CGPoint(x: controlPoint2_x, y: controlPoint2_y))
        path.addLine(to: CGPoint(x: width, y: height)) // Line down to bottom-right
        let controlPoint3_x: CGFloat = width * 0.7
        let controlPoint3_y: CGFloat = height
        let controlPoint4_x: CGFloat = width * 0.3
        let controlPoint4_y: CGFloat = startLength
        path.addCurve(to: CGPoint(x: 0, y: startLength), control1: CGPoint(x: controlPoint3_x, y: controlPoint3_y), control2: CGPoint(x: controlPoint4_x, y: controlPoint4_y)) // Curve back to start height
        path.closeSubpath()
    } else { // Bottom curve connects (0, height - startLength) to (width, 0)
        path.move(to: CGPoint(x: 0, y: height - startLength))
        let controlPoint1_x: CGFloat = width * 0.3
        let controlPoint1_y: CGFloat = height - startLength
        let controlPoint2_x: CGFloat = width * 0.7
        let controlPoint2_y: CGFloat = 0
        path.addCurve(to: CGPoint(x: width, y: 0), control1: CGPoint(x: controlPoint1_x, y: controlPoint1_y), control2: CGPoint(x: controlPoint2_x, y: controlPoint2_y))
        path.addLine(to: CGPoint(x: width, y: endLength)) // Line down to end height on right
        let controlPoint3_x: CGFloat = width * 0.7
        let controlPoint3_y: CGFloat = endLength
        let controlPoint4_x: CGFloat = width * 0.3
        let controlPoint4_y: CGFloat = height
        path.addCurve(to: CGPoint(x: 0, y: height), control1: CGPoint(x: controlPoint3_x, y: controlPoint3_y), control2: CGPoint(x: controlPoint4_x, y: controlPoint4_y)) // Curve back to bottom-left
        path.closeSubpath()
    }
    return path
}

/// Provides previews for the `PowerFlowView` in different power states.
struct PowerFlowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Example 1: Charging
            VStack {
                Text("Charging").font(.caption)
                PowerFlowView(inputPower: 60.5, batteryPower: 20.1, systemLoad: 40.4)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .previewDisplayName("Charging")

            // Example 2: Discharging (On Battery)
            VStack {
                Text("Discharging (On Battery)").font(.caption)
                PowerFlowView(inputPower: 0, batteryPower: -15.2, systemLoad: 15.2)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .previewDisplayName("Discharging")

            // Example 3: Adapter Powering System Only (Battery Full/Idle)
            VStack {
                Text("Adapter Powering System (Battery Idle)").font(.caption)
                PowerFlowView(inputPower: 30.0, batteryPower: 0, systemLoad: 30.0)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .previewDisplayName("Adapter Only")

            // Example 4: Adapter + Battery Powering System (High Load)
            VStack {
                Text("Adapter + Battery Powering System").font(.caption)
                PowerFlowView(inputPower: 90.0, batteryPower: -10.0, systemLoad: 100.0)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .previewDisplayName("Adapter + Battery")
        }
        .previewLayout(.sizeThatFits)
    }
}
