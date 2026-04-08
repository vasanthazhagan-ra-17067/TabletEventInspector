//
//  TabletEventRecord.swift
//  TabletEventInspector
//

import Cocoa

struct TabletEventRecord: Codable {
    let timestamp: Date
    let componentName: String
    let sourceMethod: String
    let eventType: String
    let eventSubtype: String
    let pressure: Float
    let tiltX: CGFloat
    let tiltY: CGFloat
    let rotation: Float
    let deviceType: String
    let isEnteringProximity: Bool?
    let locationX: CGFloat
    let locationY: CGFloat
    let vendorID: Int
    let tabletID: Int
    let pointingDeviceID: Int

    // MARK: - Helpers

    static func deviceTypeString(from event: NSEvent) -> String {
        switch event.pointingDeviceType {
        case .pen:     return "pen"
        case .eraser:  return "eraser"
        case .cursor:  return "cursor"
        default:       return "unknown"
        }
    }

    static func eventTypeString(_ type: NSEvent.EventType) -> String {
        switch type {
        case .leftMouseDown:   return "leftMouseDown"
        case .leftMouseUp:     return "leftMouseUp"
        case .leftMouseDragged: return "leftMouseDragged"
        case .rightMouseDown:  return "rightMouseDown"
        case .rightMouseUp:    return "rightMouseUp"
        case .rightMouseDragged: return "rightMouseDragged"
        case .mouseMoved:      return "mouseMoved"
        case .tabletPoint:     return "tabletPoint"
        case .tabletProximity: return "tabletProximity"
        default:               return "event(\(type.rawValue))"
        }
    }

    static func subtypeString(_ subtype: NSEvent.EventSubtype) -> String {
        switch subtype {
        case .tabletPoint:     return "tabletPoint"
        case .tabletProximity: return "tabletProximity"
        case .mouseEvent:      return "mouseEvent"
        case .touch:           return "touch"
        default:               return "subtype(\(subtype.rawValue))"
        }
    }

    /// Build from a mouse/tablet NSEvent (non-proximity).
    static func from(event: NSEvent, componentName: String, sourceMethod: String,
                     knownVendorID: Int = 0, knownTabletID: Int = 0) -> TabletEventRecord {
        let loc = event.locationInWindow
        return TabletEventRecord(
            timestamp: Date(),
            componentName: componentName,
            sourceMethod: sourceMethod,
            eventType: eventTypeString(event.type),
            eventSubtype: subtypeString(event.subtype),
            pressure: event.pressure,
            tiltX: event.tilt.x,
            tiltY: event.tilt.y,
            rotation: event.rotation,
            deviceType: deviceTypeString(from: event),
            isEnteringProximity: nil,
            locationX: loc.x,
            locationY: loc.y,
            vendorID: knownVendorID,
            tabletID: knownTabletID,
            pointingDeviceID: Int(event.pointingDeviceID)
        )
    }

    /// Build from a tabletProximity NSEvent.
    static func fromProximity(event: NSEvent, componentName: String, sourceMethod: String) -> TabletEventRecord {
        let loc = event.locationInWindow
        return TabletEventRecord(
            timestamp: Date(),
            componentName: componentName,
            sourceMethod: sourceMethod,
            eventType: "tabletProximity",
            eventSubtype: "tabletProximity",
            pressure: 0.0,
            tiltX: 0.0,
            tiltY: 0.0,
            rotation: 0.0,
            deviceType: deviceTypeString(from: event),
            isEnteringProximity: event.isEnteringProximity,
            locationX: loc.x,
            locationY: loc.y,
            vendorID: Int(event.vendorID),
            tabletID: Int(event.tabletID),
            pointingDeviceID: Int(event.pointingDeviceID)
        )
    }

    /// Build a synthetic record from a component callback (no NSEvent reference).
    static func fromCallback(componentName: String, sourceMethod: String,
                             knownVendorID: Int = 0, knownTabletID: Int = 0) -> TabletEventRecord {
        var pressure: Float = 0
        var tiltX: CGFloat = 0
        var tiltY: CGFloat = 0
        var rotation: Float = 0
        var deviceType = "unknown"
        var locX: CGFloat = 0
        var locY: CGFloat = 0
        var subtype = "unknown"
        var eventTypeStr = "unknown"
        if let e = NSApp.currentEvent {
            pressure = e.pressure
            tiltX = e.tilt.x
            tiltY = e.tilt.y
            rotation = e.rotation
            deviceType = TabletEventRecord.deviceTypeString(from: e)
            locX = e.locationInWindow.x
            locY = e.locationInWindow.y
            subtype = subtypeString(e.subtype)
            eventTypeStr = eventTypeString(e.type)
        }
        return TabletEventRecord(
            timestamp: Date(),
            componentName: componentName,
            sourceMethod: sourceMethod,
            eventType: eventTypeStr,
            eventSubtype: subtype,
            pressure: pressure,
            tiltX: tiltX,
            tiltY: tiltY,
            rotation: rotation,
            deviceType: deviceType,
            isEnteringProximity: nil,
            locationX: locX,
            locationY: locY,
            vendorID: knownVendorID,
            tabletID: knownTabletID,
            pointingDeviceID: 0
        )
    }
}
