// Power Management Suite - Main Application Entry Point
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
//  appApp.swift
//  app
// 
//  Created by tsunami on 2025/3/22.
//

import SwiftUI
import AppKit
import Cocoa

@main
struct appApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        _EmptyScene()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var sbitem: NSStatusItem!
    var eventMonitor: Any?
    var highlightTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupPopoverWindow()
        setupEventMonitor() // Keep existing call
    }

    // MARK: - Setup Methods

    private func setupStatusBarItem() {
        sbitem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = sbitem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if let originalImage = NSImage(systemSymbolName: "minus.plus.and.fluid.batteryblock", accessibilityDescription: "Battery Limit")?.withSymbolConfiguration(config) {
            // Create a new image with padding for visual centering in the status bar.
            let paddedImage = NSImage(size: NSSize(width: originalImage.size.width, height: originalImage.size.height + 4))
            paddedImage.lockFocus()

            // Draw the original image offset vertically (y: 2) to center it within the padded space.
            let drawRect = NSRect(
                x: 0,
                y: 2, // Vertical offset for centering
                width: originalImage.size.width,
                height: originalImage.size.height
            )
            originalImage.draw(in: drawRect)

            paddedImage.unlockFocus()
            paddedImage.isTemplate = true // Ensures proper appearance in light/dark mode

            button.image = paddedImage
        }
        button.target = self
        button.action = #selector(sbiClick)
    }

    private func setupPopoverWindow() {
        
        // Create the main content view using SwiftUI
        // Remove fixed frame to allow adaptive sizing
        // Inject the uiState into ContentView
        let swiftUIContentView = ContentView()
            // .frame(width: 300, height: 450, alignment: .top) // REMOVED
            .padding(0) // Add padding around the content

        // Host the SwiftUI view within an NSHostingView
        // NSHostingView will intrinsically size based on swiftUIContentView
        let hostingView = NSHostingView(rootView: swiftUIContentView)
        // hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 450) // REMOVED
        hostingView.autoresizingMask = [.width, .height] // Keep autoresizing
        // Restore layer setup for hostingView (though clipping is handled by backgroundView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true // This might be redundant if backgroundView clips

        let intrinsicSize = hostingView.fittingSize

        // Create the visual effect view for the blurred background
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.frame = hostingView.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.cornerCurve = .continuous
        // visualEffectView.layer?.masksToBounds = true // Clipping handled by backgroundView

        // Add the hosting view as a subview of the visual effect view
        visualEffectView.addSubview(hostingView)

        // Re-add intermediate background view for clipping
        let backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
        backgroundView.layer?.cornerRadius = 16
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.borderWidth = 0.5
        backgroundView.layer?.borderColor = NSColor.separatorColor.cgColor
        backgroundView.layer?.masksToBounds = true // Clip subviews (visualEffectView)

        backgroundView.addSubview(visualEffectView)

        // Create the NSPanel (popover window)
        // Initialize with zero rect, it will resize to fit contentView
        let panel = NSPanel(
            contentRect: .zero, // Use .zero rect
            styleMask: [.borderless, .nonactivatingPanel], // Borderless, doesn't activate app
            backing: .buffered,
            defer: false
        )

        // Configure the panel's appearance and behavior
        panel.isOpaque = false // Allows transparency
        panel.backgroundColor = .clear // Transparent background
        panel.level = .floating // Keep panel above other windows
        panel.isReleasedWhenClosed = false // Keep panel instance in memory
        // panel.hasShadow = true // Optional: Add a system shadow if desired

        // Set the intermediate background view as the panel's content view
        panel.contentView = backgroundView // Use backgroundView for clipping

        // Explicitly set the panel's content size based on the SwiftUI view's needs
        panel.setContentSize(intrinsicSize)

        // Assign the configured panel to the window property
        self.window = panel

    }

    func setupEventMonitor() {
        // Monitor global mouse clicks to close the popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.window.isVisible else { return }
            
            // 检查点击是否在窗口范围外
            if let eventWindow = event.window, eventWindow == self.window {
                return // 点击在窗口内，不处理
            }
            
            // 点击在窗口外，关闭窗口
            self.closePopover()
        }
    }
    
    deinit {
        stopHighlightTimer()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @objc
    func sbiClick() {
        if window.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        guard let bt = sbitem.button else { return }
        guard let wo = bt.window else { return }
        
        // 高亮按钮
        startButtonHighlight()
        
        // 定位和显示窗口
        let x = wo.frame.midX - window.frame.width / 2
        let y = wo.frame.origin.y - 5
        
        window.setFrameTopLeftPoint(NSPoint(x: x, y: y))
        //window.makeKeyAndOrderFront(nil)
        window.orderFront(nil)
    }
    
    func closePopover() {
        // 停止高亮
        stopHighlightTimer()
        
        // 确保按钮取消高亮
        sbitem.button?.highlight(false)
        
        // 关闭窗口
        window.orderOut(nil)
    }
    
    // MARK: - Highlight Control
    
    private func startButtonHighlight() {
        // Stop any existing highlight timer
        stopHighlightTimer()
        
        // Immediately highlight the button
        sbitem.button?.highlight(true)
        
        // Use a timer to repeatedly ensure the button remains highlighted.
        // This is necessary because the non-activating panel might cause
        // the button to lose its highlight state otherwise.
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.sbitem.button?.highlight(true)
            let cs = self?.window.contentView?.subviews[0].subviews[0].fittingSize
            let ws = self?.window.frame.size
            if cs != ws {
                self?.window.setContentSize(cs!)
            }
        }
    }
    
    private func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
    }
    
    // NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        // 窗口失去焦点时关闭
        if window.isVisible {
            closePopover()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        stopHighlightTimer()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
}

extension AppDelegate {
    private func setupQuitMenuItem() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitMenuItem)

        appMenuItem.submenu = appMenu
        NSApplication.shared.mainMenu = mainMenu
    }
}
