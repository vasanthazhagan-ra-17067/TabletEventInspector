//
//  ComponentShowcaseViewController.swift
//  TabletEventInspector
//
//  Tab 2: Live VTComponentsUI components with direct event logging.
//  Each component has:
//    1. A high-level hook (delegate/actionBlock/closure) — logs what the component surfaces.
//    2. rawEventLogger — injected closure that logs the raw NSEvent delivery channel
//       directly from inside the component (no wrapper view needed).
//

import Cocoa
import VTComponentsUI_Mac

final class ComponentShowcaseViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()

    // Retained objects that must live as long as this VC
    private var retainedDelegates: [AnyObject] = []
    private weak var overflowFeedback: NSTextField?
    private weak var chipFeedback: NSTextField?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.orientation = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let clipView = scrollView.contentView
        scrollView.documentView = contentStack

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: clipView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -16)
        ])

        addTitle()
        buildComponents()
    }

    private func addTitle() {
        let label = NSTextField(labelWithString: "Tab 2 — Component Showcase (Dual-Layer Logging)")
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        contentStack.addArrangedSubview(label)

        let sub = NSTextField(wrappingLabelWithString:
            "Each component shows two log entries per interaction:\n" +
            "  • Component hook — what the callback/delegate surfaces\n" +
            "  • rawEventLogger — exact NSEvent delivery channel (mouse vs tabletPoint subtype)"
        )
        sub.font = NSFont.systemFont(ofSize: 11)
        sub.textColor = .secondaryLabelColor
        sub.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(sub)

        let sep = NSBox()
        sep.boxType = .separator
        contentStack.addArrangedSubview(sep)
    }

    // MARK: - Component rows

    private func buildComponents() {
        addRow_ZLabelView()
        addRow_ZCButton()
        addRow_ZToggleButton()
        addRow_ToggleButton()
        addRow_ZCheckbox()
        addRow_ZRadioButton()
        addRow_ZBadgeView()
        addRow_ZSegmentControl()
        addRow_ZOverflowButton()
        addRow_ZLabelChipView()
    }

    // MARK: - Individual component builders

    private func addRow_ZLabelView() {
        let comp = ZLabelView()
        comp.setString(string: "ZLabelView — tap me", font: NSFont.systemFont(ofSize: 13), color: .labelColor)
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZLabelView")
        let fb = makeFeedbackLabel()
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZLabelView",
                                    hookDescription: "ZLabelDelegate → clicked(field:)",
                                    reset: { [weak fb] in
                                        fb?.stringValue = "—"
                                        fb?.textColor = .tertiaryLabelColor
                                    })
        let d = ClosureZLabelDelegate { [weak fb] in
            fb?.stringValue = "✅ clicked"
            fb?.textColor   = .systemGreen
        }
        comp.customDelegate = d
        retainedDelegates.append(d)
    }

    private func addRow_ZCButton() {
        let comp = ZCButton(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        comp.title = "ZCButton"
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZCButton")
        let fb = makeFeedbackLabel()
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZCButton",
                                    hookDescription: "actionBlock",
                                    reset: { [weak fb] in
                                        fb?.stringValue = "—"
                                        fb?.textColor = .tertiaryLabelColor
                                    })
        comp.actionBlock = { [weak fb] _ in
            fb?.stringValue = "✅ action fired"
            fb?.textColor   = .systemGreen
        }
    }

    private func addRow_ZToggleButton() {
        let theme = ZToggleButton.Theme(
            onStateBgColor: .systemBlue,
            offStateBgColor: .systemGray,
            disabledOnStateBgColor: .systemBlue.withAlphaComponent(0.4),
            disabledOffStateBgColor: .systemGray.withAlphaComponent(0.4),
            knobOnStateColor: .white,
            knobOffStateColor: .white,
            disabledKnobOnStateColor: .white.withAlphaComponent(0.6),
            disabledKnobOffStateColor: .white.withAlphaComponent(0.6),
            borderWidth: 0,
            onStateBorderColor: .clear,
            offStateBorderColor: .clear,
            disabledOnStateBorderColor: .clear,
            disabledOffStateBorderColor: .clear
        )
        let comp = ZToggleButton(buttonState: .off, isDisabled: false, knobRadius: 9.0, theme: theme)
        // Fix: pin toggle to pill shape; knobRadius=9 → knob diameter=18, container height=22
        comp.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            comp.widthAnchor.constraint(equalToConstant: 50),
            comp.heightAnchor.constraint(equalToConstant: 22)
        ])
        comp.setCorner(radius: 11)   // height / 2 = pill shape
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZToggleButton")
        let fb = makeFeedbackLabel()
        fb.stringValue = "OFF"
        fb.textColor = .secondaryLabelColor
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZToggleButton",
                                    hookDescription: "action closure",
                                    reset: { [weak comp, weak fb] in
                                        comp?.changeToggleState(state: .off, animate: false,
                                                                isDisabled: false, callback: {})
                                        fb?.stringValue = "OFF"
                                        fb?.textColor = .secondaryLabelColor
                                    })
        // Remove the row helper's min-size constraints that would conflict with the
        // exact width/height pinned above.
        comp.constraints
            .filter { ($0.firstAttribute == .width || $0.firstAttribute == .height)
                       && $0.relation == .greaterThanOrEqual }
            .forEach { $0.isActive = false }
        comp.action = { [weak fb] btn in
            let newState: ToggleState = btn.buttonState == .on ? .off : .on
            btn.changeToggleState(state: newState, animate: true, isDisabled: false, callback: {})
            fb?.stringValue = newState == .on ? "ON" : "OFF"
            fb?.textColor   = newState == .on ? .systemGreen : .secondaryLabelColor
        }
    }

    private func addRow_ToggleButton() {
        let comp = ToggleButton(toggleType: .label)
        comp.cornerRadius = 14
        comp.leadingTextLabel.stringValue  = "ON"
        comp.trailingTextLabel.stringValue = "OFF"
        var tTheme = ToggleButton.Theme()
        tTheme.offStateBgColor             = .systemGray
        tTheme.onStateBgColor              = .systemBlue
        tTheme.offStateKnobBgColor         = .white
        tTheme.onStateKnobBgColor          = .white
        tTheme.offStateLeadingTextColor    = .white.withAlphaComponent(0.4)
        tTheme.offStateTrailingTextColor   = .white
        tTheme.onStateLeadingTextColor     = .white
        tTheme.onStateTrailingTextColor    = .white.withAlphaComponent(0.4)
        comp.theme = tTheme
        comp.rawEventLogger = makeRawEventLogger(componentName: "ToggleButton")
        let fb = makeFeedbackLabel()
        fb.stringValue = "OFF"
        fb.textColor = .secondaryLabelColor
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ToggleButton",
                                    hookDescription: "actionBlock",
                                    reset: { [weak comp, weak fb] in
                                        comp?.changeState(state: .off, withAnimation: false)
                                        fb?.stringValue = "OFF"
                                        fb?.textColor = .secondaryLabelColor
                                    })
        comp.actionBlock = { [weak fb] btn in
            let isOn = btn.state == .on
            fb?.stringValue = isOn ? "ON" : "OFF"
            fb?.textColor   = isOn ? .systemGreen : .secondaryLabelColor
        }
    }

    private func addRow_ZCheckbox() {
        let comp = ZCheckbox(title: "ZCheckbox")
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZCheckbox")
        let fb = makeFeedbackLabel()
        fb.stringValue = "☐ unchecked"
        fb.textColor = .secondaryLabelColor
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZCheckbox",
                                    hookDescription: "actionCallback",
                                    reset: { [weak comp, weak fb] in
                                        comp?.state = false
                                        fb?.stringValue = "☐ unchecked"
                                        fb?.textColor = .secondaryLabelColor
                                    })
        comp.actionCallback = { [weak fb] cb in
            fb?.stringValue = cb.state ? "☑ checked" : "☐ unchecked"
            fb?.textColor   = cb.state ? .systemGreen : .secondaryLabelColor
        }
    }

    private func addRow_ZRadioButton() {
        let fb    = makeFeedbackLabel()
        fb.stringValue = "○ unselected"
        fb.textColor = .secondaryLabelColor
        let theme = SimpleRadioTheme()
        let comp  = ZRadioButton(isSelected: false, title: "ZRadioButton",
                                 action: { [weak fb] btn in
                                     guard let radio = btn as? ZRadioButton else { return }
                                     let newState = !radio.getSelectionState()
                                     radio.changeSelectionMode(isSelected: newState)
                                     fb?.stringValue = newState ? "◉ selected" : "○ unselected"
                                     fb?.textColor   = newState ? .systemGreen : .secondaryLabelColor
                                 }, theme: theme)
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZRadioButton")
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZRadioButton", hookDescription: "action closure",
                                    reset: { [weak comp, weak fb] in
                                        comp?.changeSelectionMode(isSelected: false)
                                        fb?.stringValue = "○ unselected"
                                        fb?.textColor = .secondaryLabelColor
                                    })
    }

    private func addRow_ZBadgeView() {
        let comp = ZBadgeView(
            withSize: 24,
            badgeColor: .systemBlue,
            outlineColor: .clear,
            outlineThickness: 0,
            textColor: .white,
            textFont: NSFont.boldSystemFont(ofSize: 11),
            cornerRadius: 12
        )
        comp.badgeCount = 5
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZBadgeView")
        let fb = makeFeedbackLabel()
        fb.stringValue = "count: 5"
        fb.textColor = .secondaryLabelColor
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZBadgeView",
                                    hookDescription: "actionBlock",
                                    reset: { [weak comp, weak fb] in
                                        comp?.badgeCount = 5
                                        fb?.stringValue = "count: 5"
                                        fb?.textColor = .secondaryLabelColor
                                    })
        comp.actionBlock = { [weak fb, weak comp] _ in
            comp?.badgeCount += 1
            let c = comp?.badgeCount ?? 0
            fb?.stringValue = "count: \(c)"
            fb?.textColor   = .systemGreen
        }
    }

    private func addRow_ZSegmentControl() {
        let fb   = makeFeedbackLabel()
        fb.stringValue = "Seg A"
        fb.textColor = .secondaryLabelColor
        let data = [
            ZSegmentData(image: nil, label: "Seg A", type: .labelOnly, isSelected: true,
                         identifier: NSUserInterfaceItemIdentifier("A")),
            ZSegmentData(image: nil, label: "Seg B", type: .labelOnly, isSelected: false,
                         identifier: NSUserInterfaceItemIdentifier("B"))
        ]
        let comp = ZSegmentControl(
            data: data,
            segmentType: .labelOnly,
            segmentDistribution: .fit,
            target: nil,
            action: nil,
            actionBlock: { [weak fb] seg in
                let id = seg.identifierOfSelectedSegment?.rawValue ?? "?"
                fb?.stringValue = "Seg \(id)"
                fb?.textColor   = .systemGreen
            }
        )
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZSegmentControl")
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZSegmentControl", hookDescription: "actionBlock",
                                    reset: { [weak comp, weak fb] in
                                        _ = comp?.selectSegment(at: 0)
                                        fb?.stringValue = "Seg A"
                                        fb?.textColor = .secondaryLabelColor
                                    })
    }

    private func addRow_ZOverflowButton() {
        let comp = ZOverflowButton(additionalSize: NSSize(width: 12, height: 6))
        comp.set(title: "More ▾",
                 font: NSFont.systemFont(ofSize: 12),
                 color: .labelColor,
                 backgroundColor: NSColor.controlColor,
                 isSelected: false)
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZOverflowButton")
        comp.delegate = self
        let fb = makeFeedbackLabel()
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZOverflowButton",
                                    hookDescription: "ZOverflowButtonDelegate → showPopup",
                                    reset: { [weak fb] in
                                        fb?.stringValue = "—"
                                        fb?.textColor = .tertiaryLabelColor
                                    })
        overflowFeedback = fb
    }

    private func addRow_ZLabelChipView() {
        let theme = SimpleChipTheme()
        let comp  = ZLabelChipView(theme: theme)
        comp.setLabel(string: "Priority")
        comp.setChipLabel(string: "High")
        comp.rawEventLogger = makeRawEventLogger(componentName: "ZLabelChipView")
        comp.delegate = self
        // Fix: pin natural content width to prevent unbounded growth
        comp.translatesAutoresizingMaskIntoConstraints = false
        comp.widthAnchor.constraint(equalToConstant: 160).isActive = true
        let fb = makeFeedbackLabel()
        addComponentRowWithFeedback(component: comp, feedback: fb,
                                    name: "ZLabelChipView",
                                    hookDescription: "ZLabelChipViewDelegate → didClickOnLabelView",
                                    reset: { [weak fb] in
                                        fb?.stringValue = "—"
                                        fb?.textColor = .tertiaryLabelColor
                                    })
        chipFeedback = fb
    }

    // MARK: - Raw event logger factory

    /// Returns a closure that converts raw NSEvents into TabletEventRecord entries
    /// and appends them to EventLogStore. Injected into each component's rawEventLogger.
    private func makeRawEventLogger(componentName: String) -> (NSEvent, String) -> Void {
        let label = "[\(componentName)]"
        return { event, base in
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
                    knownVendorID: EventLogStore.shared.lastVendorID,
                    knownTabletID: EventLogStore.shared.lastTabletID
                )
                EventLogStore.shared.append(record)
            }
        }
    }

    // MARK: - Row layout helpers

    /// Builds a row card, returns the feedback label placed to the right of the component.
    @discardableResult
    private func addComponentRow(component: NSView,
                                 name: String,
                                 hookDescription: String,
                                 reset: (() -> Void)? = nil) -> NSTextField {
        let fb = makeFeedbackLabel()
        addComponentRowWithFeedback(component: component, feedback: fb,
                                    name: name, hookDescription: hookDescription,
                                    reset: reset)
        return fb
    }

    private func addComponentRowWithFeedback(component: NSView,
                                             feedback: NSTextField,
                                             name: String,
                                             hookDescription: String,
                                             reset: (() -> Void)? = nil) {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.layer?.cornerRadius = 6
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.borderWidth = 0.5
        container.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = NSFont.boldSystemFont(ofSize: 12)
        nameLabel.textColor = .labelColor
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let hookLabel = NSTextField(labelWithString: hookDescription)
        hookLabel.font = NSFont.systemFont(ofSize: 10)
        hookLabel.textColor = .secondaryLabelColor
        hookLabel.translatesAutoresizingMaskIntoConstraints = false

        component.translatesAutoresizingMaskIntoConstraints = false
        // Keep component at its natural content width
        component.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        container.addSubview(nameLabel)
        container.addSubview(hookLabel)
        container.addSubview(component)
        container.addSubview(feedback)

        let minH: CGFloat = max(28, component.intrinsicContentSize.height > 0
                                    ? component.intrinsicContentSize.height : 28)

        var constraints: [NSLayoutConstraint] = [
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -10),

            hookLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            hookLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            hookLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -10),

            // Component — left side, minimum width 160 pt
            component.topAnchor.constraint(equalTo: hookLabel.bottomAnchor, constant: 8),
            component.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            component.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            component.heightAnchor.constraint(greaterThanOrEqualToConstant: minH),
            component.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),

            // Feedback label — centred vertically beside the component
            feedback.leadingAnchor.constraint(equalTo: component.trailingAnchor, constant: 12),
            feedback.centerYAnchor.constraint(equalTo: component.centerYAnchor)
        ]

        if let resetAction = reset {
            let resetBtn = ZCButton(frame: .zero)
            resetBtn.title = "↺"
            resetBtn.translatesAutoresizingMaskIntoConstraints = false
            resetBtn.actionBlock = { _ in resetAction() }
            container.addSubview(resetBtn)
            constraints += [
                feedback.trailingAnchor.constraint(lessThanOrEqualTo: resetBtn.leadingAnchor, constant: -8),
                resetBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
                resetBtn.centerYAnchor.constraint(equalTo: component.centerYAnchor),
                resetBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 30)
            ]
        } else {
            constraints.append(
                feedback.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -10)
            )
        }

        NSLayoutConstraint.activate(constraints)
        contentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func makeFeedbackLabel() -> NSTextField {
        let lbl = NSTextField(labelWithString: "—")
        lbl.font = NSFont.systemFont(ofSize: 11)
        lbl.textColor = .tertiaryLabelColor
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }
}

// MARK: - ZOverflowButtonDelegate

extension ComponentShowcaseViewController: ZOverflowButtonDelegate {
    func showPopup(sender: ZOverflowButton) {
        overflowFeedback?.stringValue = "✅ showPopup"
        overflowFeedback?.textColor   = .systemGreen
    }
}

// MARK: - ZLabelChipViewDelegate

extension ComponentShowcaseViewController: ZLabelChipViewDelegate {
    func didClickOnLabelView() {
        chipFeedback?.stringValue = "✅ didClick"
        chipFeedback?.textColor   = .systemGreen
    }
}

// MARK: - ClosureZLabelDelegate

private final class ClosureZLabelDelegate: NSObject, ZLabelDelegate {
    private let onClicked: () -> Void
    init(onClicked: @escaping () -> Void) { self.onClicked = onClicked }
    func clicked(field: ZLabelView) { onClicked() }
}

// MARK: - Minimal theme implementations

private final class SimpleRadioTheme: ZRadioButtonTheme {
    var radioHeadingButton_Font: NSFont = NSFont.systemFont(ofSize: 13)
    var radioHeadingButton_Font_Color: NSColor = .labelColor
    var radioHeadingButton_Border_Color: NSColor = .systemGray
    var radioHeadingButton_Border_Size: CGFloat = 1
    var radioHeadingButton_BackgroundColor: NSColor = .windowBackgroundColor

    var radioHeadingButton_Font_Selected: NSFont = NSFont.boldSystemFont(ofSize: 13)
    var radioHeadingButton_Font_Color_Selected: NSColor = .labelColor
    var radioHeadingButton_Border_Size_Selected: CGFloat = 2
    var radioHeadingButton_Border_Color_Selected: NSColor = .systemGreen
    var radioHeadingButton_BackgroundColor_Selected: NSColor = .systemGreen.withAlphaComponent(0.15)

    var radioButtonFillStyle: NSColor = .clear
    var radioButtonFillStyle_Selected: NSColor = .systemGreen
}

private final class SimpleChipTheme: ZLabelChipTheme {
    var chipLabel_Font: NSFont = NSFont.systemFont(ofSize: 12)
    var chipLabel_Font_Color: NSColor = .labelColor
    var closeButton: NSImage? = nil
    var chipContainer_Background: NSColor = .systemBlue
    var label_Font: NSFont = NSFont.systemFont(ofSize: 11)
    var label_Font_Color: NSColor = .labelColor
}

