//
//  EventLogViewController.swift
//  TabletEventInspector
//
//  Tab 4: Centralized event log table.
//  Columns: Timestamp | Component | Source Method | Event Type | Subtype |
//           Pressure | Tilt X | Tilt Y | Device Type | Proximity
//

import Cocoa

final class EventLogViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var records: [TabletEventRecord] = []

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        EventLogStore.shared.addObserver { [weak self] records in
            self?.records = records
            // tableView may not be loaded yet; guard before touching UI
            guard self?.isViewLoaded == true else { return }
            self?.tableView.reloadData()
            self?.scrollToBottom()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildTable()
        buildToolbar()
        // Populate table with any records already collected before this tab loaded
        records = EventLogStore.shared.records
        tableView.reloadData()
        scrollToBottom()
    }

    // MARK: - Table setup

    private let columnDefs: [(id: String, title: String, width: CGFloat)] = [
        ("timestamp",  "Timestamp",    90),
        ("component",  "Component",   140),
        ("method",     "Source Method", 200),
        ("eventType",  "Event Type",   120),
        ("subtype",    "Subtype",      110),
        ("pressure",   "Pressure",      70),
        ("tiltX",      "Tilt X",        60),
        ("tiltY",      "Tilt Y",        60),
        ("deviceType", "Device Type",   90),
        ("proximity",  "Proximity",    100)
    ]

    private func buildTable() {
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 22
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.delegate = self
        tableView.dataSource = self

        for colDef in columnDefs {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(colDef.id))
            col.title = colDef.title
            col.width = colDef.width
            col.minWidth = 50
            tableView.addTableColumn(col)
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildToolbar() {
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearLog))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Tab 4 — Event Log")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.tag = 1001

        view.addSubview(titleLabel)
        view.addSubview(clearButton)
        view.addSubview(countLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: clearButton.centerYAnchor),

            clearButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            countLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: clearButton.centerYAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func clearLog() {
        // Delegate all state updates to the observer registered in viewDidLoad.
        // EventLogStore.clear() notifies observers async on main queue, which
        // updates self.records, reloads the table, and resets the count label.
        EventLogStore.shared.clear()
    }

    private func scrollToBottom() {
        let row = records.count - 1
        if row >= 0 {
            tableView.scrollRowToVisible(row)
        }
        if let countLabel = view.viewWithTag(1001) as? NSTextField {
            countLabel.stringValue = "\(records.count) events"
        }
    }
}

// MARK: - NSTableViewDataSource

extension EventLogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { records.count }
}

// MARK: - NSTableViewDelegate

extension EventLogViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < records.count, let col = tableColumn else { return nil }
        let record = records[row]

        let cellId = NSUserInterfaceItemIdentifier("Cell")
        let cellView: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cellView = existing
        } else {
            cellView = NSTableCellView()
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            cellView.addSubview(tf)
            cellView.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            cellView.identifier = cellId
        }

        cellView.textField?.stringValue = cellValue(for: col.identifier.rawValue, record: record)
        return cellView
    }

    private func cellValue(for colID: String, record: TabletEventRecord) -> String {
        switch colID {
        case "timestamp":  return dateFormatter.string(from: record.timestamp)
        case "component":  return record.componentName
        case "method":     return record.sourceMethod
        case "eventType":  return record.eventType
        case "subtype":    return record.eventSubtype
        case "pressure":   return String(format: "%.2f", record.pressure)
        case "tiltX":      return String(format: "%.2f", record.tiltX)
        case "tiltY":      return String(format: "%.2f", record.tiltY)
        case "deviceType": return record.deviceType
        case "proximity":
            if let p = record.isEnteringProximity {
                return p ? "entering" : "leaving"
            }
            return "—"
        default: return ""
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { nil }
}
