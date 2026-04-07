//
//  TabletCanvasView.swift
//  TabletEventInspector
//
//  Tab 1 raw probe: a plain NSView that intercepts all tablet/mouse delivery channels.
//

import Cocoa

final class TabletCanvasView: NSView {

    private let componentName = "TabletCanvas"

    // Local monitor for dedicated tabletPoint / tabletProximity events
    private var localMonitor: Any?

    // Last known device IDs from proximity events
    private var lastVendorID: Int = 0
    private var lastTabletID: Int = 0

    // Visual feedback label
    private let hintLabel: NSTextField = {
        let f = NSTextField(labelWithString: "Hover or press your stylus here.\nAll delivery channels are logged.")
        f.alignment = .center
        f.textColor = .secondaryLabelColor
        f.font = NSFont.systemFont(ofSize: 14)
        f.isEditable = false
        f.isBordered = false
        f.drawsBackground = false
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    private let lastEventLabel: NSTextField = {
        let f = NSTextField(labelWithString: "—")
        f.alignment = .center
        f.textColor = .labelColor
        f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        f.isEditable = false
        f.isBordered = false
        f.drawsBackground = false
        f.lineBreakMode = .byWordWrapping
        f.maximumNumberOfLines = 4
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1

        addSubview(hintLabel)
        addSubview(lastEventLabel)

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            hintLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40),

            lastEventLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            lastEventLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            lastEventLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -40)
        ])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startLocalMonitor()
        } else {
            stopLocalMonitor()
        }
    }

    private func startLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.tabletPoint, .tabletProximity]) { [weak self] event in
            self?.handleLocalMonitorEvent(event)
            return event
        }
    }

    private func stopLocalMonitor() {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
    }

    // MARK: - Dedicated tablet event channels

    override func tabletPoint(with event: NSEvent) {
        let record = TabletEventRecord.from(
            event: event,
            componentName: componentName,
            sourceMethod: "tabletPoint(with:)",
            knownVendorID: lastVendorID,
            knownTabletID: lastTabletID
        )
        log(record)
    }

    override func tabletProximity(with event: NSEvent) {
        lastVendorID = Int(event.vendorID)
        lastTabletID = Int(event.tabletID)
        let record = TabletEventRecord.fromProximity(
            event: event,
            componentName: componentName,
            sourceMethod: "tabletProximity(with:)"
        )
        log(record)
    }

    // MARK: - Mouse events (check for embedded tablet subtype)

    override func mouseDown(with event: NSEvent) {
        log(record(from: event, method: "mouseDown"))
    }

    override func mouseUp(with event: NSEvent) {
        log(record(from: event, method: "mouseUp"))
    }

    override func mouseDragged(with event: NSEvent) {
        log(record(from: event, method: "mouseDragged"))
    }

    override func rightMouseDown(with event: NSEvent) {
        log(record(from: event, method: "rightMouseDown"))
    }

    override func rightMouseUp(with event: NSEvent) {
        log(record(from: event, method: "rightMouseUp"))
    }

    override func rightMouseDragged(with event: NSEvent) {
        log(record(from: event, method: "rightMouseDragged"))
    }

    // MARK: - Local monitor handler

    private func handleLocalMonitorEvent(_ event: NSEvent) {
        let method: String
        let record: TabletEventRecord
        if event.type == .tabletProximity {
            lastVendorID = Int(event.vendorID)
            lastTabletID = Int(event.tabletID)
            method = "localMonitor tabletProximity"
            record = TabletEventRecord.fromProximity(event: event, componentName: componentName, sourceMethod: method)
        } else {
            method = "localMonitor tabletPoint"
            record = self.record(from: event, method: method)
        }
        log(record)
    }

    // MARK: - Helpers

    private func record(from event: NSEvent, method: String) -> TabletEventRecord {
        let sourceMethod: String
        if event.subtype == .tabletPoint {
            sourceMethod = "\(method) [tabletPoint subtype]"
        } else if event.subtype == .tabletProximity {
            sourceMethod = "\(method) [tabletProximity subtype]"
        } else {
            sourceMethod = method
        }
        return TabletEventRecord.from(
            event: event,
            componentName: componentName,
            sourceMethod: sourceMethod,
            knownVendorID: lastVendorID,
            knownTabletID: lastTabletID
        )
    }

    private func log(_ record: TabletEventRecord) {
        EventLogStore.shared.append(record)
        DispatchQueue.main.async { [weak self] in
            self?.lastEventLabel.stringValue = "[\(record.sourceMethod)]\npressure: \(record.pressure)  tilt: (\(String(format: "%.2f", record.tiltX)), \(String(format: "%.2f", record.tiltY)))"
        }
    }
}
