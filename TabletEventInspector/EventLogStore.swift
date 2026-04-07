//
//  EventLogStore.swift
//  TabletEventInspector
//
//  In-memory observable store shared across all tabs.
//

import Foundation

final class EventLogStore {

    static let shared = EventLogStore()

    private(set) var records: [TabletEventRecord] = []
    private var observers: [(([TabletEventRecord]) -> Void)] = []

    // Known device identifiers populated from proximity events
    private(set) var lastVendorID: Int = 0
    private(set) var lastTabletID: Int = 0

    private init() {}

    func append(_ record: TabletEventRecord) {
        // Update device IDs when we see a proximity event
        if record.vendorID != 0 {
            lastVendorID = record.vendorID
            lastTabletID = record.tabletID
        }
        records.append(record)
        EventLogger.shared.log(record)
        notifyObservers()
    }

    func clear() {
        records.removeAll()
        notifyObservers()
    }

    // MARK: - Observer subscription

    func addObserver(_ observer: @escaping ([TabletEventRecord]) -> Void) {
        observers.append(observer)
    }

    private func notifyObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.observers.forEach { $0(self.records) }
        }
    }
}
