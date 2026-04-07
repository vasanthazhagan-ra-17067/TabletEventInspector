# Plan: TabletEventInspector — Tablet Event Reception Research App

## Background / Bug

A user reported that clicking a `ZLabelView` (used as a button) does nothing when using a **Huion tablet stylus**. The same interaction works correctly with a **Wacom tablet**.

**`ZLabelView` click mechanism (from source):**
```
mouseDown    →  dragFlag = false
mouseDragged →  dragFlag = true        ← BUG TRIGGER
mouseUp      →  if dragFlag == false → clicked()   ← SUPPRESSED if drag was detected
```

**Three leading hypotheses for Huion failure:**
1. **Huion driver sends a spurious `mouseDragged` between pen-down and pen-up** — even tiny position jitter sets `dragFlag = true`, permanently suppressing the click. Wacom doesn't do this.
2. **Huion delivers events as raw `tabletPoint` events only** — not wrapped as mouse events — so `mouseDown`/`mouseUp` on `ZLabelView` (an `NSTextField`) never fire at all. Wacom wraps tablet data cleanly as `mouseDown [tabletPoint subtype]`.
3. **Huion sends `mouseDragged` instead of `mouseDown` for initial contact** — the driver maps pen-touch differently.

**End goal:** Gather exact event sequences from the Huion user's machine, compare with Wacom baseline, confirm the hypothesis, then fix `ZLabelView` (and other components) accordingly.

---

## Goal

Determine **how macOS delivers tablet/stylus events to our app** — specifically whether a stylus interaction arrives as a dedicated tablet event (`tabletPoint(with:)` / `tabletProximity(with:)`) or is translated into a mouse event with an embedded tablet subtype. This is tested on a raw `NSView` baseline, through real VTComponentsUI-macOS components, and with a focused `ZLabelView` diagnostic view designed to isolate the Huion bug.

---

## Architecture

```
NSWindow
  └─ NSTabViewController (.toolbar style, 4 tabs)
       ├─ Tab 1: ViewController                  — Tablet Canvas (raw probe)
       ├─ Tab 2: ComponentShowcaseViewController  — Live VTComponents + raw event overlay
       ├─ Tab 3: ZLabelDiagnosticViewController   — Focused ZLabelView bug diagnostic
       └─ Tab 4: EventLogViewController           — Centralized event log table

Shared:
  TabletEventRecord.swift  — data struct
  EventLogger.swift        — file-based log writer (~/.../events.log)
  EventLogStore.swift      — in-memory observable store (feeds Tab 4 table)
```

---

## Tab 1: Tablet Canvas (Baseline Raw Probe)

A plain `NSView` subclass (`TabletCanvasView`) with no component interference. Intercepts all three delivery channels:

| Channel | Method Overridden | Logged sourceMethod |
|---|---|---|
| Dedicated tablet | `tabletPoint(with:)` | `"tabletPoint(with:)"` |
| Dedicated proximity | `tabletProximity(with:)` | `"tabletProximity(with:)"` |
| Mouse + tablet subtype | `mouseDown`, `mouseUp`, `mouseDragged`, `rightMouseDown`, `rightMouseUp`, `rightMouseDragged` — check `event.subtype` | `"mouseDown [tabletPoint subtype]"` etc. |
| NSEvent local monitor | `addLocalMonitorForEvents(matching: [.tabletPoint, .tabletProximity])` | `"localMonitor"` |

`mouseMoved` intentionally excluded (too frequent).

---

## Tab 2: Component Showcase (VTComponents + Event Overlay)

Each of the 16 VTComponentsUI components is rendered as a live, interactable instance. Two layers of observation run simultaneously per component:

1. **High-level hook** — the component's own delegate/callback/closure fires → logs `"ZButton.mouseEntered"` etc.
2. **Raw event overlay** — an `EventLogWrapper: NSView` wraps each component, overrides `mouseDown/Up/Dragged`, `tabletPoint(with:)`, `tabletProximity(with:)` → logs the raw delivery channel (e.g. `"[ZButton wrapper] mouseDown [tabletPoint subtype]"`)

This dual logging reveals the relationship: what the component's callback surfaces vs. what the underlying NSEvent actually was.

### Components and Their High-Level Hooks

| Component | High-Level Hook | Logged sourceMethod |
|---|---|---|
| `ZLabelView` | `ZLabelDelegate.clicked`, `.dragged` | `"ZLabelView.clicked"`, `".dragged"` |
| `ZButton` | `ZButtonDelegate.mouseEntered/Exited` | `"ZButton.mouseEntered"`, `".mouseExited"` |
| `ZCButton` | `actionBlock`, `mouserEnteredObserver`, `mouseExitedObserver` | `"ZCButton.action"`, `".entered"`, `".exited"` |
| `ZImageButton` | `mouseEnteredObserver`, `mouseExitedObserver` | `"ZImageButton.entered"`, `".exited"` |
| `ZCustomButton` | `actionBlock` | `"ZCustomButton.action"` |
| `ZDraggableButton` | No callback — raw overlay only | `"[ZDraggableButton wrapper] mouseDown"` |
| `ZFilterButton` | No callback — raw overlay only | `"[ZFilterButton wrapper] mouseDown"` |
| `ZFormButton` | `actionBlock` | `"ZFormButton.action"` |
| `ZHoverButton` | `actionBlock` | `"ZHoverButton.action"` |
| `ZToggleButton` | `action` closure | `"ZToggleButton.action"` |
| `ToggleButton` | `actionBlock` | `"ToggleButton.action"` |
| `ZCheckbox` | `actionCallback` | `"ZCheckbox.action"` |
| `ZRadioButton` | `action` closure | `"ZRadioButton.action"` |
| `ZBadgeView` | `actionBlock` | `"ZBadgeView.action"` |
| `ZSegmentControl` | `actionBlock` | `"ZSegmentControl.action"` |
| `ZOverflowButton` | `ZOverflowButtonDelegate.showPopup` | `"ZOverflowButton.showPopup"` |
| `ZLabelChipView` | `ZLabelChipViewDelegate.didClickOnLabelView` | `"ZLabelChipView.didClick"` |

For callbacks that don't pass an `NSEvent`, use `NSApp.currentEvent` to extract tablet properties (pressure, tilt, subtype).

---

## Tab 3: ZLabelView Bug Diagnostic (Huion Focus)

`ZLabelDiagnosticViewController` — a dedicated focused view for isolating the Huion bug.

### Layout
- **Device Info panel** (top) — auto-populated from the first proximity event: Vendor ID, Tablet ID, Pointing Device Serial, Device Type, `isEnteringProximity`. Stays visible so the user can confirm Huion is detected vs. Wacom.
- **ZLabelView instance** (center, large hit target ~300×80pt, labeled "Tap me with your stylus") — the exact VTComponentsUI `ZLabelView` with a real `customDelegate`.
- **Tap Result indicator** — large status text: `✅ CLICKED` or `❌ SUPPRESSED (drag detected)` — updates live on each pen-down+up cycle.
- **Last Tap Sequence box** — ordered list of every event received during the last pen-down→pen-up window:
  ```
  1. mouseDown [tabletPoint subtype] — pressure 0.42
  2. mouseDragged [tabletPoint subtype] — pressure 0.41  ← dragFlag set!
  3. mouseUp [tabletPoint subtype] — pressure 0.00
  Result: SUPPRESSED
  ```
- **Drag Event Counter** — "Drag events in last tap: 3" — the number of `mouseDragged` events fired between down and up. Even 1 = click suppressed.
- **dragFlag State indicator** — live color badge (green = false, red = true) showing current dragFlag state (mirrored via `EventLogWrapper` subclass wrapping the ZLabelView).

### What This Proves
| Observation | Hypothesis Confirmed |
|---|---|
| `mouseDragged` fires between down and up | Hypothesis 1 — Huion sends spurious drag events |
| Only `tabletPoint(with:)` fires, no mouseDown | Hypothesis 2 — Huion uses raw tablet events, bypassing mouse chain |
| `mouseDragged` fires first with no preceding `mouseDown` | Hypothesis 3 — Huion maps pen-down as drag |
| No events fire at all | Driver not installed or events going elsewhere |

### Additional Controls
- **"Copy Device Info"** button — copies vendor ID, tablet ID, serial, driver version string to clipboard for the user to paste into a bug report
- **"Reveal Log in Finder"** button — opens `~/Library/Logs/TabletEventInspector/` in Finder so the user can attach `events.log` to a support ticket

---

## Tab 4: Event Log Table (renamed from Tab 3)

**Columns:** Timestamp | Component | Source Method | Event Type | Subtype | Pressure | Tilt X | Tilt Y | Device Type | Proximity

- Clear button resets in-memory store + reloads table (log file retains full history)
- Auto-scrolls to newest entry
- `EventLogStore` is an observable array; Tab 4 subscribes to updates from Tab 1, Tab 2, and Tab 3

---

## Shared Infrastructure

### TabletEventRecord (data struct)
```
timestamp: Date
componentName: String     // "TabletCanvas", "ZButton", "[ZButton wrapper]", "localMonitor"
sourceMethod: String      // the key diagnostic field
eventType: String         // NSEvent.EventType description
eventSubtype: String      // NSEvent.EventSubtype description
pressure: Float
tiltX: CGFloat
tiltY: CGFloat
rotation: Float
deviceType: String        // pen / eraser / cursor / unknown
isEnteringProximity: Bool?
locationInWindow: NSPoint
// Device identification fields (from proximity events)
vendorID: Int             // distinguishes Wacom vs Huion at hardware level
tabletID: Int
pointingDeviceSerialNumber: Int
pointingDeviceID: Int
```

### EventLogger (file writer)
- Path: `~/Library/Logs/TabletEventInspector/events.log`
- `EventLogger.shared.log(_ record: TabletEventRecord)`
- Opens `FileHandle` once; appends immediately on each call (no buffering — crash-safe)
- **Format: JSON Lines (NDJSON)** — one self-contained JSON object per line. Human-readable with clear field names, AI-parseable, works with `jq`.

**Example entry (tap with Huion stylus on ZLabelView):**
```json
{
  "timestamp": "2026-04-07T14:32:05.812Z",
  "component": "ZLabelView",
  "sourceMethod": "mouseDown [tabletPoint subtype]",
  "eventType": "leftMouseDown",
  "eventSubtype": "tabletPoint",
  "pressure": 0.43,
  "tiltX": -0.12,
  "tiltY": 0.05,
  "rotation": 0.0,
  "deviceType": "pen",
  "isEnteringProximity": null,
  "locationX": 412.5,
  "locationY": 308.0,
  "vendorID": 9580,
  "tabletID": 312,
  "pointingDeviceSerialNumber": 0,
  "pointingDeviceID": 1
}
```

**Example proximity entry (Huion pen hover):**
```json
{
  "timestamp": "2026-04-07T14:32:05.100Z",
  "component": "TabletCanvas",
  "sourceMethod": "tabletProximity(with:)",
  "eventType": "tabletProximity",
  "eventSubtype": "tabletProximity",
  "pressure": 0.0,
  "tiltX": 0.0,
  "tiltY": 0.0,
  "rotation": 0.0,
  "deviceType": "pen",
  "isEnteringProximity": true,
  "locationX": 400.0,
  "locationY": 300.0,
  "vendorID": 9580,
  "tabletID": 312,
  "pointingDeviceSerialNumber": 0,
  "pointingDeviceID": 1
}
```

- Each line is a complete valid JSON object — append `[` at top and `]` at bottom to get a valid JSON array if needed
- `null` used for fields that don't apply (e.g. `isEnteringProximity` is null for non-proximity events; vendor IDs are 0 if not yet seen from a proximity event)
- Readable in any text editor; can be queried with `jq '.sourceMethod' events.log` etc.

### EventLogStore (in-memory store)
- `EventLogStore.shared.append(_ record: TabletEventRecord)` — called from all sources
- Internally calls `EventLogger.shared.log(record)` too
- Tab 4's `EventLogViewController` reads from this store and reloads on update

---

## File List

| File | Action |
|---|---|
| `TabletEventInspector/AppDelegate.swift` | EDIT — NSWindow + NSTabViewController (3 tabs), remove IBOutlet |
| `TabletEventInspector/ViewController.swift` | NEW — Tab 1: TabletCanvasView + local monitor |
| `TabletEventInspector/ComponentShowcaseViewController.swift` | NEW — Tab 2: 16 components + wrappers |
| `TabletEventInspector/EventLogViewController.swift` | NEW — Tab 3: NSTableView log |
| `TabletEventInspector/TabletCanvasView.swift` | NEW — NSView with all tablet/mouse overrides |
| `TabletEventInspector/EventLogWrapper.swift` | NEW — NSView wrapper for raw overlay on each component |
| `TabletEventInspector/TabletEventRecord.swift` | NEW — data struct |
| `TabletEventInspector/EventLogger.swift` | NEW — file writer |
| `TabletEventInspector/EventLogStore.swift` | NEW — in-memory store shared across all tabs |
| `TabletEventInspector/ZLabelDiagnosticViewController.swift` | NEW — Tab 3: ZLabelView bug diagnostic |
| VTComponentsUI dependency | Via CocoaPods: `VTComponentsUI_Mac ~> 1.0.210` (Podfile already set up) |
| `TabletEventInspector/Base.lproj/MainMenu.xib` | NO CHANGES |

---

## VTComponentsUI Dependency

Added via CocoaPods in the existing Podfile:
```ruby
pod 'VTComponentsUI_Mac', '~> 1.0.210'
pod 'VTComponents', '~> 2.0.4'
```
Run `pod install` and open `TabletEventInspector.xcworkspace`.

---

## Verification

1. App launches; four tabs visible: "Tablet Inspector", "Component Showcase", "ZLabel Diagnostic", "Event Log"
2. Tab 1: Hover stylus → proximity entries appear in Tab 4 log; press → down/drag/up entries; `sourceMethod` column reveals delivery channel
3. Tab 2: Stylus on `ZCheckbox` → two entries per tap: component hook + raw wrapper; subtype column shows whether it arrived as mouse or tablet event
4. **Tab 3 (key diagnostic):** Tap `ZLabelView` with Huion stylus:
   - Device Info panel shows Huion vendor/tablet ID
   - Last Tap Sequence lists every event in order
   - If `❌ SUPPRESSED` → Drag Event Counter > 0 → confirms Hypothesis 1
   - If no mouse events at all → confirms Hypothesis 2
5. User clicks "Reveal Log in Finder" and attaches `events.log` to support ticket
6. Repeat Tab 3 test with Wacom → `✅ CLICKED`, Drag Counter = 0 → baseline confirmed

---

## Decisions / Scope

- **4 tabs:** Canvas | Components | ZLabel Diagnostic | Log
- **Fully programmatic** — no XIB modifications
- **No SwiftUI** — NSViewController + NSView throughout
- **Dual-layer logging on Tab 2** — both component hook AND raw wrapper event logged per interaction
- **Tab 3 is the primary deliverable** for the Huion bug — it gives the user a clear PASS/FAIL result and captures the exact event sequence to share with the team
- `NSApp.currentEvent` used when component callback doesn't pass an NSEvent reference
- **Out of scope:** Drawing ink, stylus pressure visuals, global monitoring (requires Accessibility)

---

## Likely Fix (Post-Diagnosis)

Depending on what Tab 3 reveals:

| Finding | Fix |
|---|---|
| Huion sends spurious `mouseDragged` on tap | Add a position-delta threshold in `ZLabelView.mouseDragged` — only set `dragFlag = true` if movement > ~4px |
| Huion uses raw `tabletPoint` events only | Override `tabletPoint(with:)` in `ZLabelView` to treat it as a click (check pressure > 0 = down, pressure = 0 = up) |
| Both patterns | Apply both fixes |

The fix should be applied in `ZLabelView` in VTComponentsUI-macOS and tested by re-running Tab 3 after the patch.
