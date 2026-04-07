//
//  AppDelegate.swift
//  TabletEventInspector
//
//  Created by vignesh-13338-t on 06/04/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar

        let tab1VC = ViewController()
        tab1VC.title = "Tablet Inspector"

        let tab2VC = ComponentShowcaseViewController()
        tab2VC.title = "Component Showcase"

        let tab3VC = ZLabelDiagnosticViewController()
        tab3VC.title = "ZLabel Diagnostic"

        let tab4VC = EventLogViewController()
        tab4VC.title = "Event Log"

        let item1 = NSTabViewItem(viewController: tab1VC)
        item1.label = "Tablet Inspector"
        let item2 = NSTabViewItem(viewController: tab2VC)
        item2.label = "Component Showcase"
        let item3 = NSTabViewItem(viewController: tab3VC)
        item3.label = "ZLabel Diagnostic"
        let item4 = NSTabViewItem(viewController: tab4VC)
        item4.label = "Event Log"

        tabVC.addTabViewItem(item1)
        tabVC.addTabViewItem(item2)
        tabVC.addTabViewItem(item3)
        tabVC.addTabViewItem(item4)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false
        )
        win.title = "Tablet Event Inspector"
        win.contentViewController = tabVC
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

