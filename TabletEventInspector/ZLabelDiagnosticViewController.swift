//
//  ZLabelDiagnosticViewController.swift
//  TabletEventInspector
//
//  Tab 3: Focused ZLabelView bug diagnostic for the Huion vs Wacom issue.
//  Shows device info, tap result, last tap sequence, drag counter, and dragFlag state.
//

import Cocoa
import VTComponentsUI_Mac

final class ZLabelDiagnosticViewController: NSViewController {

    // MARK: - Device info panel

    private let vendorLabel     = makeMono("Vendor ID: —")
    private let tabletLabel     = makeMono("Tablet ID: —")
    private let serialLabel     = makeMono("Serial: —")
    private let deviceTypeLabel = makeMono("Device Type: —")
    private let proximityLabel  = makeMono("Proximity: —")

    private let copyDeviceInfoButton: NSButton = {
        let b = NSButton(title: "Copy Device Info", target: nil, action: nil)
        b.bezelStyle = .rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - ZLabelView + diagnostic monitors

    private let zLabelView: ZLabelView = {
        let v = ZLabelView()
        v.setString(string: "Tap me with your stylus", font: NSFont.systemFont(ofSize: 18), color: .labelColor)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        v.layer?.cornerRadius = 8
        v.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        v.layer?.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Result indicators

    private let tapResultLabel: NSTextField = {
        let f = NSTextField(labelWithString: "—")
        f.font = NSFont.boldSystemFont(ofSize: 20)
        f.alignment = .center
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    // MARK: - Tap sequence

    private let sequenceTextView: NSTextView = {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textColor = .labelColor
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Drag counter

    private let dragCountLabel: NSTextField = {
        let f = NSTextField(labelWithString: "Drag events in last tap: 0")
        f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    // MARK: - dragFlag badge

    private let dragFlagBadge: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        v.layer?.backgroundColor = NSColor.systemGreen.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let dragFlagLabel: NSTextField = {
        let f = NSTextField(labelWithString: "dragFlag: false")
        f.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    // MARK: - Bottom buttons

    private let revealLogButton: NSButton = {
        let b = NSButton(title: "Reveal Log in Finder", target: nil, action: nil)
        b.bezelStyle = .rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let resetButton: NSButton = {
        let b = NSButton(title: "Reset", target: nil, action: nil)
        b.bezelStyle = .rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - State tracking

    private var currentTapSequence: [(String, Float)] = []   // (sourceMethod, pressure)
    private var dragCountInTap: Int = 0
    private var isDragFlagSet: Bool = false

    // Proximity info
    private var lastVendorID: Int = 0
    private var lastTabletID: Int = 0
    private var lastSerial: Int = 0
    private var lastDeviceType: String = "—"

    private var localMonitor: Any?
    private var mouseMonitor: Any?
    /// Tracks whether the current drag gesture started inside the ZLabelView.
    private var tapInProgress = false

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        zLabelView.customDelegate = self
        zLabelView.rawEventLogger = makeRawEventLogger(componentName: "ZLabelView")

        buildLayout()
        wireButtons()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        startLocalMonitor()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        stopLocalMonitor()
    }

    // MARK: - Layout

    private func buildLayout() {
        // ---- dragFlag row ----
        dragFlagBadge.widthAnchor.constraint(equalToConstant: 16).isActive = true
        dragFlagBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let dragFlagRow = NSStackView(views: [dragFlagBadge, dragFlagLabel])
        dragFlagRow.orientation = .horizontal
        dragFlagRow.spacing = 6

        // ---- Sequence scroll (fixed height, fills width via stack) ----
        let seqScroll = NSScrollView()
        seqScroll.hasVerticalScroller = true
        seqScroll.autohidesScrollers = true
        seqScroll.documentView = sequenceTextView
        seqScroll.translatesAutoresizingMaskIntoConstraints = false
        seqScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true

        // ---- Title / instruction ----
        let title = NSTextField(labelWithString: "ZLabelView Huion Bug Diagnostic")
        title.font = NSFont.boldSystemFont(ofSize: 13)
        title.textColor = .secondaryLabelColor

        let instruction = NSTextField(wrappingLabelWithString:
            "Tap the label once with your stylus. Green ✅ CLICKED = no drag detected. " +
            "Red ❌ SUPPRESSED = Huion sent spurious drag events between pen-down and pen-up."
        )
        instruction.font = NSFont.systemFont(ofSize: 11)
        instruction.textColor = .secondaryLabelColor
        instruction.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // ---- Section headers ----
        let deviceHeader  = sectionHeader("Device Info (from proximity)")
        let resultHeader  = sectionHeader("Tap Result")
        let seqHeader     = sectionHeader("Last Tap Sequence")
        let diagHeader    = sectionHeader("Tap Target")

        let sep1 = separator()
        let sep2 = separator()
        let sep3 = separator()

        // ---- Device info sub-stack ----
        let deviceStack = NSStackView(views: [vendorLabel, tabletLabel, serialLabel,
                                              deviceTypeLabel, proximityLabel, copyDeviceInfoButton])
        deviceStack.orientation = .vertical
        deviceStack.alignment = .leading
        deviceStack.spacing = 3

        // ---- Main vertical stack ----
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let arranged: [NSView] = [
            title, instruction, sep1,
            deviceHeader, deviceStack, sep2,
            diagHeader, zLabelView, sep3,
            resultHeader, tapResultLabel,
            seqHeader, seqScroll,
            dragCountLabel, dragFlagRow,
            revealLogButton, resetButton
        ]
        arranged.forEach { mainStack.addArrangedSubview($0) }

        // Stretch most items to fill the stack width
        let fillItems: [NSView] = [instruction, sep1, deviceStack, sep2,
                                   zLabelView, sep3, seqScroll,
                                   dragCountLabel, dragFlagRow]
        fillItems.forEach {
            $0.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }

        // ZLabelView: tall hit target, fills width
        zLabelView.heightAnchor.constraint(equalToConstant: 80).isActive = true

        // ---- Scroll container ----
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = mainStack
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // mainStack must be at least as wide as the scroll clip view
            mainStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor, constant: -16)
        ])
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.boldSystemFont(ofSize: 11)
        f.textColor = .secondaryLabelColor
        return f
    }

    private func separator() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        return b
    }

    private func wireButtons() {
        copyDeviceInfoButton.target = self
        copyDeviceInfoButton.action = #selector(copyDeviceInfo)
        revealLogButton.target = self
        revealLogButton.action = #selector(revealLog)
        resetButton.target = self
        resetButton.action = #selector(resetState)
    }

    // MARK: - Tap sequence tracking

    private func handleDown(_ event: NSEvent) {
        currentTapSequence = []
        dragCountInTap = 0
        isDragFlagSet = false
        updateDragFlagBadge(false)
        appendToSequence(event: event, label: "mouseDown")
    }

    private func handleDragged(_ event: NSEvent) {
        dragCountInTap += 1
        isDragFlagSet = true
        updateDragFlagBadge(true)
        appendToSequence(event: event, label: "mouseDragged ← dragFlag set!")
    }

    private func handleUp(_ event: NSEvent) {
        appendToSequence(event: event, label: "mouseUp")
        updateSequenceDisplay()
    }

    private func appendToSequence(event: NSEvent, label: String) {
        let subStr = event.subtype == .tabletPoint ? " [tabletPoint subtype]" :
                     event.subtype == .tabletProximity ? " [tabletProximity subtype]" : ""
        currentTapSequence.append(("\(label)\(subStr)", event.pressure))
    }

    private func updateSequenceDisplay() {
        var lines: [String] = []
        for (i, (method, pressure)) in currentTapSequence.enumerated() {
            lines.append("\(i + 1). \(method) — pressure \(String(format: "%.2f", pressure))")
        }
        dragCountLabel.stringValue = "Drag events in last tap: \(dragCountInTap)"
        sequenceTextView.string = lines.joined(separator: "\n")
    }

    private func updateDragFlagBadge(_ isSet: Bool) {
        dragFlagBadge.layer?.backgroundColor = isSet ? NSColor.systemRed.cgColor : NSColor.systemGreen.cgColor
        dragFlagLabel.stringValue = "dragFlag: \(isSet)"
    }

    // MARK: - Proximity monitoring

    private func startLocalMonitor() {
        guard localMonitor == nil else { return }

        // Proximity events — update device info panel
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .tabletProximity) { [weak self] event in
            self?.handleProximityEvent(event)
            return event
        }

        // Left mouse events — track tap sequence directly on the ZLabelView.
        // We use a monitor instead of the wrapper's overrides because AppKit
        // sends events to the deepest accepting subview (ZLabelView itself),
        // so the wrapper's mouseDown/Dragged/Up never fire.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.trackMouseEvent(event)
            return event
        }
    }

    private func stopLocalMonitor() {
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor  { NSEvent.removeMonitor(m) }
        localMonitor = nil
        mouseMonitor = nil
    }

    /// Routes left-mouse events to the tap-sequence tracker.
    /// Only tracks events that start inside the ZLabelView's bounds.
    private func trackMouseEvent(_ event: NSEvent) {
        guard let window = zLabelView.window, event.window === window else { return }
        let locInLabel = zLabelView.convert(event.locationInWindow, from: nil)
        let inside = zLabelView.bounds.contains(locInLabel)

        switch event.type {
        case .leftMouseDown:
            guard inside else { return }
            tapInProgress = true
            handleDown(event)
        case .leftMouseDragged:
            guard tapInProgress else { return }
            handleDragged(event)
        case .leftMouseUp:
            guard tapInProgress else { return }
            tapInProgress = false
            handleUp(event)
        default:
            break
        }
    }

    private func handleProximityEvent(_ event: NSEvent) {
        lastVendorID = Int(event.vendorID)
        lastTabletID = Int(event.tabletID)
        lastSerial = Int(event.pointingDeviceSerialNumber)
        lastDeviceType = TabletEventRecord.deviceTypeString(from: event)

        vendorLabel.stringValue     = "Vendor ID: \(lastVendorID)"
        tabletLabel.stringValue     = "Tablet ID: \(lastTabletID)"
        serialLabel.stringValue     = "Serial: \(lastSerial)"
        deviceTypeLabel.stringValue = "Device Type: \(lastDeviceType)"
        proximityLabel.stringValue  = "Entering Proximity: \(event.isEnteringProximity)"
    }

    // MARK: - Button actions

    @objc private func copyDeviceInfo() {
        let info = """
        Vendor ID: \(lastVendorID)
        Tablet ID: \(lastTabletID)
        Serial: \(lastSerial)
        Device Type: \(lastDeviceType)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    @objc private func revealLog() {
        NSWorkspace.shared.activateFileViewerSelecting([EventLogger.shared.logFilePublicURL])
    }

    @objc private func resetState() {
        currentTapSequence = []
        dragCountInTap = 0
        isDragFlagSet = false
        tapInProgress = false

        tapResultLabel.stringValue = "—"
        tapResultLabel.textColor = .labelColor
        sequenceTextView.string = ""
        dragCountLabel.stringValue = "Drag events in last tap: 0"
        updateDragFlagBadge(false)
    }

    // MARK: - Factory helpers

    private static func makeMono(_ s: String) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func makeRawEventLogger(componentName: String) -> (NSEvent, String) -> Void {
        let label = "[\(componentName)]"
        return { [weak self] event, base in
            guard let self else { return }
            if base == "tabletProximity(with:)" {
                let record = TabletEventRecord.fromProximity(
                    event: event,
                    componentName: label,
                    sourceMethod: base
                )
                EventLogStore.shared.append(record)
            } else {
                let sourceMethod: String
                if event.subtype == .tabletPoint {
                    sourceMethod = "\(base) [tabletPoint subtype]"
                } else if event.subtype == .tabletProximity {
                    sourceMethod = "\(base) [tabletProximity subtype]"
                } else {
                    sourceMethod = base
                }
                let record = TabletEventRecord.from(
                    event: event,
                    componentName: label,
                    sourceMethod: sourceMethod,
                    knownVendorID: self.lastVendorID,
                    knownTabletID: self.lastTabletID
                )
                EventLogStore.shared.append(record)
            }
        }
    }
}

// MARK: - ZLabelDelegate

extension ZLabelDiagnosticViewController: ZLabelDelegate {
    func clicked(field: ZLabelView) {
        tapResultLabel.stringValue = "✅ CLICKED"
        tapResultLabel.textColor = .systemGreen

        let record = TabletEventRecord.fromCallback(
            componentName: "ZLabelView",
            sourceMethod: "ZLabelView.clicked",
            knownVendorID: lastVendorID,
            knownTabletID: lastTabletID
        )
        EventLogStore.shared.append(record)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateSequenceDisplay()
        }
    }
}

// MARK: - Free function for makeMono (file-level helper)

private func makeMono(_ s: String) -> NSTextField {
    let f = NSTextField(labelWithString: s)
    f.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    f.translatesAutoresizingMaskIntoConstraints = false
    return f
}
