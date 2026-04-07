//
//  ViewController.swift
//  TabletEventInspector
//
//  Tab 1: Tablet Canvas — raw probe view.
//

import Cocoa

final class ViewController: NSViewController {

    private let canvasView = TabletCanvasView()

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = NSTextField(labelWithString: "Tab 1 — Tablet Canvas (Raw Probe)")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let instructionLabel = NSTextField(wrappingLabelWithString:
            "Interact directly on the canvas below using your stylus or mouse. " +
            "Every delivery channel (tabletPoint, tabletProximity, mouse+subtype, localMonitor) " +
            "is captured and sent to the Event Log (Tab 4)."
        )
        instructionLabel.font = NSFont.systemFont(ofSize: 12)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        canvasView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(instructionLabel)
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            canvasView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 12),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }
}
