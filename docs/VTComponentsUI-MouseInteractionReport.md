# VTComponentsUI-macOS — Mouse & User Interaction Report

> Detailed analysis of how each interactive component in `VTComponentsUI-macOS` handles user events.

---

## 1. ZLabelView

**Base class:** `NSTextField`  
**Interaction mechanism:** `ZLabelDelegate` (click, right-click), `ZLabelDraggedDelegate` (drag)

### Mouse Flow

```
mouseDown  →  resets dragFlag = false
mouseDragged  →  sets dragFlag = true, calls dragDelegate?.dragged(...)
mouseUp  →  if dragFlag == false → calls customDelegate?.clicked(field:)
              if dragFlag == true → suppressed (drag took precedence)
rightMouseUp  →  calls customDelegate?.rightClicked(field:)
mouseEntered  →  sets NSCursor.arrow
```

### Key Logic / Catch

- **Drag-suppresses-click pattern:** A private `dragFlag` is reset to `false` on `mouseDown`. If `mouseDragged` is called before `mouseUp`, it sets `dragFlag = true`. In `mouseUp`, the delegate click is **only called if `dragFlag == false`** — so dragging never accidentally fires a click.
- The `shouldListenDragActions` flag (default `true`) controls whether drag events are forwarded. If `false`, `mouseDragged` calls `super` and does **not** set `dragFlag`, so clicks still fire.
- When `dragDelegate` is set, `mouseDownCanMoveWindow` returns `false`, preventing the window from being dragged instead.
- When neither delegate is set, all events fall through to `super`.

---

## 2. ZButton

**Base class:** `NSButton`  
**Interaction mechanism:** `ZButtonDelegate` (hover only)

### Mouse Flow

```
mouseEntered  →  delegate?.mouseEntered(button:event:)
mouseExited   →  delegate?.mouseExited(button:event:)
click         →  handled by NSButton natively (action/target)
```

### Key Logic

- Tracking area uses `.activeInActiveApp + .mouseEnteredAndExited`.
- `updateTrackingAreas()` removes the old area and creates a fresh one bound to current `bounds`.
- The delegate only covers **hover**, not clicks. Clicks use the standard NSButton `action`/`target` mechanism.
- Also enforces minimum HGI size (16×16) via `viewWillDraw`.

---

## 3. ZCButton

**Base class:** `NSButton`  
**Interaction mechanism:** Closures (`actionBlock`, `mouseMoveObserver`, `mouserEnteredObserver`, `mouseExitedObserver`, `stateChangeObserver`)

### Mouse Flow

```
mouseEntered  →  mouserEnteredObserver?(self, event)
mouseExited   →  mouseExitedObserver?(self, event)
mouseMoved    →  mouseMoveObserver?(self, event)
click/action  →  sendAction override → actionBlock?(self), then super.sendAction
state change  →  stateChangeObserver?(self)
```

### Key Logic

- Tracking area uses `.inVisibleRect + .mouseEnteredAndExited + .activeAlways` — set in `init`.
- `sendAction` is **intercepted**: `actionBlock` fires first, then the standard target-action goes through. Both can coexist.
- Supports custom `NSCursor` via `cursor` property — set in `resetCursorRects()`.
- `stateChangeObserver` is triggered via `state` didSet, but only when the value actually changes (`guard oldValue != state`).
- `CustomBgButtonCell` draws state-aware backgrounds (normal / highlighted / selected / inactive / disabled).

---

## 4. ZImageButton

**Base class:** `NSButton`  
**Interaction mechanism:** Closures (`mouseEnteredObserver`, `mouseExitedObserver`) + optional `NSEvent` local monitor

### Mouse Flow (when `needsTracking = true`)

```
mouseEntered  →  isMouseIn = true
                 mouseEnteredObserver?(self)
                 applies hoverColor background + cornerRadius
mouseExited   →  mouseExitedObserver?(self)
                 isMouseIn = false
                 clears background to .clear
```

### Key Logic / Catch

- Tracking area only added when `needsTracking = true` (opt-in), using `.inVisibleRect + .mouseEnteredAndExited + .mouseMoved + .activeInActiveApp`.
- Additionally installs a **`NSEvent.addLocalMonitorForEvents`** for `leftMouseDown`, `rightMouseDown`, `otherMouseDown`. On each mouse-down anywhere in the window, it converts the location to local bounds and manually calls `mouseEntered` or `mouseExited`. This is a workaround for cases where the standard tracking area might miss a mouse-down that happens to be inside.
- The local monitor is removed in `deinit`.

---

## 5. ZCustomButton

**Base class:** `NSButton`  
**Interaction mechanism:** `actionBlock` closure + optional tracking area for hover highlight

### Mouse Flow (when `isTracking = true`)

```
mouseEntered  →  sets ZCustomButtonCell.isHighlight = true → needsDisplay = true
mouseExited   →  sets ZCustomButtonCell.isHighlight = false → needsDisplay = true
click/action  →  sendAction override → actionBlock?(self), then super
```

### Key Logic

- `isTracking` is a property — setting it **adds or removes** the tracking area dynamically (via `didSet`).
- The cell (`ZCustomButtonCell`) draws different visual states: normal, selected, highlighted, selectedHighlighted, inactive, inactiveSelected, disabled — all based on the `Style` struct.
- Listens to `NSApplication.didBecomeActiveNotification` and `didResignActiveNotification` to force redraw when the window focus changes.
- `actionBlock` fires **before** the standard `super.sendAction`.

---

## 6. ZDraggableButton

**Base class:** `NSButton`  
**Interaction mechanism:** Cursor-change only (no delegates/callbacks)

### Mouse Flow

```
mouseEntered  →  NSCursor.openHand.set()
mouseMoved    →  NSCursor.openHand.set()
mouseDown     →  NSCursor.closedHand.set(), super.mouseDown
mouseExited   →  NSCursor.arrow.set()
```

### Key Logic

- `mouseDownCanMoveWindow` returns `true` — the window moves when the button is dragged.
- Tracking area uses `.enabledDuringMouseDrag` so cursor updates continue while a drag is in progress.
- No action callback is exposed — interaction is **visual only**; consumers use standard NSButton `action`/`target`.

---

## 7. ZFilterButton

**Base class:** `NSButton`  
**Interaction mechanism:** Hover color only (no delegates/callbacks)

### Mouse Flow

```
mouseEntered  →  if hoverColor != nil && !isSelected → setBackground(hoverColor)
mouseExited   →  setBackground(backgroundColor ?? .clear)
click         →  standard NSButton action/target
```

### Key Logic

- Hover is **guarded by `isSelected`**: if the button is already selected, `mouseEntered` does nothing (selection color takes precedence over hover color).
- Tracking is opt-in via `needsTracking` init parameter (default `true`).

---

## 8. ZFormButton / ZHoverButton

**Base class:** `NSButton`  
**Interaction mechanism:** `actionBlock` closure + hover state tracking

> Both classes are **nearly identical** in implementation. `ZHoverButton` adds a `supportsDynamicWidth` flag.

### Mouse Flow

```
mouseEntered  →  mouseInside = true
                 applies imgPosition (if set)
                 if hoverColor != nil && !isSelected → setBackground(hoverColor)
mouseExited   →  mouseInside = false
                 if showsImageOnlyWhenMouseInside → imagePosition = .noImage
                 if isSelected → setBackground(hoverColor ?? backgroundColor)
                 else → setBackground(backgroundColor ?? .clear)
sendAction    →  actionBlock?(self), then super
```

### Key Logic / Catch

- The `mouseInside` flag is private and only affects `intrinsicContentSize` when `applyOffsetOnlyWhenImageOutside = true`.
- Tracking area is **lazy** — only created when `needsTracking = true` OR `showsImageOnlyWhenMouseInside = true`. Setting either of these triggers `removeTracking() + initTracking()`.
- `showsImageOnlyWhenMouseInside`: on `mouseExited`, image position is forced to `.noImage`, effectively hiding the image when the mouse leaves.
- `isSelected` affects exit behavior: a selected button reverts to `hoverColor` (not `backgroundColor`), keeping a "selected but not hovered" visual distinct from "hovered".

---

## 9. ZToggleButton

**Base class:** `NSView`  
**Interaction mechanism:** `action` closure (on mouseDown) + `mouseEnteredObserver` / `mouseExitedObserver`

### Mouse Flow

```
mouseDown    →  if !isDisabled → action?(self)
                always calls superview?.mouseDown(with:event)
mouseEntered →  mouseEnteredObserver?(self, event)
mouseExited  →  mouseExitedObserver?(self, event)
```

### Key Logic / Catch

- **Click fires on `mouseDown`**, not `mouseUp` — faster response but no cancel-on-drag.
- The `isDisabled` guard is checked before calling `action`. Visual state (colors) is controlled separately by calling `changeToggleState(state:animate:isDisabled:callback:)`.
- After `mouseDown`, the event is forwarded to `superview` — allowing parent views to handle selection logic.
- Uses `NSView.frameDidChangeNotification` to reposition the knob when the frame resizes.
- Knob animation uses `NSView.animate` with `CAMediaTimingFunction(.easeOut)`.

---

## 10. ToggleButton

**Base class:** `NSView`  
**Interaction mechanism:** Invisible overlay `ZCButton` covering the full view

### Mouse Flow

```
click on view  →  overlayButton (ZCButton, alpha=0) captures the click
                  overlayButton.actionBlock fires →
                  changeState(state:) is called →
                  actionBlock(self) is called on ToggleButton
```

### Key Logic / Catch

- The actual click is **never handled by the view's own mouse events**. An invisible `ZCButton` (alpha=0) is placed above all subviews and sized to fill the entire `ToggleButton`.
- When the overlay captures a click, it toggles the state and calls `ToggleButton.actionBlock`.
- Visual state change animates the knob via `NSView.animate` with `.easeOut` timing.

---

## 11. ZCheckbox

**Base class:** `NSView`  
**Interaction mechanism:** `mouseUp` on the wrapper + internal `NSButton`

### Mouse Flow

```
mouseDown  →  empty override (swallows the event, no super call)
mouseUp    →  converts event location to local bounds
              guard bounds.contains(viewLocation) else { return }
              button.performClick(self)  →  @objc buttonClicked()
              state.toggle()
              actionCallback?(self)
```

### Key Logic / Catch

- **`mouseDown` is explicitly empty** — this prevents the default NSView/NSButton click sound and any default behavior.
- `mouseUp` does a **bounds check** before firing: if the cursor exited the view between mouseDown and mouseUp (drag-out), the click is cancelled.
- The internal `NSButton` has `highlightsBy = []` (no visual highlight) and `imageDimsWhenDisabled = false` — pure custom visual.
- Enabling/disabling the checkbox toggles both the internal button's `isEnabled` and the visual appearance.

---

## 12. ZRadioButton

**Base class:** `NSView`  
**Interaction mechanism:** Dual path — `mouseDown` on wrapper + invisible `ZCButton`

### Mouse Flow — Path A (Direct mouseDown)

```
mouseDown  →  self.action(self)  [immediate, no mouseUp guard]
```

### Mouse Flow — Path B (Transparent ZCButton)

```
click on transparentButton  →  @objc buttonClicked()  →  self.action(self)
```

### Key Logic / Catch

- The same `action` callback can fire **twice** if both `mouseDown` on the wrapper and the overlay button respond — this is a potential double-fire bug. In practice, the overlay button sits above the content, so the button typically captures the event first.
- `mouseDown` has **no bounds check or drag guard** — any mouseDown fires the action immediately.
- The transparent overlay button uses `target = self / action = #selector(buttonClicked)` (NSButton action-target pattern), not a closure.

---

## 13. ZBadgeView

**Base class:** `NSControl`  
**Interaction mechanism:** `mouseUp` fires `sendAction`, which calls `actionBlock`

### Mouse Flow

```
mouseDown  →  walks up superview chain to find NSTableView → table.mouseDown(with:event)
mouseUp    →  self.sendAction(action, to: target)
              walks up superview chain to find NSTableView → table.mouseUp(with:event)
              also calls actionBlock?(self)
```

### Key Logic / Catch

- `ZBadgeView` **propagates** mouse events upward to any parent `NSTableView` — it is designed to be embedded in table rows without blocking row selection.
- Click fires on `mouseUp`.
- `sendAction` override additionally calls `actionBlock`, so both target-action and closure patterns can coexist.

---

## 14. ZSegmentControl / ZSegment

**ZSegmentControl base:** `NSView` | **ZSegment base:** `NSView` (fileprivate)  
**Interaction mechanism:** `mouseUp` on `ZSegment` → delegate → `actionBlock` on `ZSegmentControl`

### Mouse Flow

```
ZSegment.mouseUp  →  select()  →  delegate?.segmentSelected(segment:)
                                  ZSegmentControl.actionBlock?(self)
```

### Key Logic

- `ZSegment` is **fileprivate** — only `ZSegmentControl` manages them.
- Click fires on `mouseUp` (not `mouseDown`) — consistent with macOS conventions.
- No drag guard is present on the segment level.

---

## 15. ZOverflowButton

**Base class:** `NSView`  
**Interaction mechanism:** `mouseDown` on wrapper + internal `ZFilterButton` (action-target)

### Mouse Flow — Path A (Wrapper mouseDown)

```
mouseDown  →  delegate?.showPopup(sender: self)
```

### Mouse Flow — Path B (Internal ZFilterButton)

```
click on button  →  #selector(showPopup)  →  delegate?.showPopup(sender: self)
```

### Hover Flow

```
mouseEntered  →  if hoverColor != nil && !isSelected → setBackground(hoverColor)
mouseExited   →  setBackground(backgroundColor ?? .clear)
```

### Key Logic / Catch

- `showPopup` can fire via **two paths** simultaneously. The internal `ZFilterButton` has `target = self, action = #selector(showPopup)`, so clicking it calls `showPopup()`. But the wrapper's `mouseDown` also calls the delegate directly — meaning both fire on a standard click.
- In practice, `ZFilterButton` has no title/image set, so it acts as a transparent hit-target, with the visible area rendered by `imageView`.

---

## 16. ZLabelChipView

**Base class:** `NSView`  
**Interaction mechanism:** `mouseDown` hit-tests subviews + `ZLabelChipViewDelegate`

### Mouse Flow

```
mouseDown  →  convert event location to local coords
              hitTest(pointInSelf) to identify clicked subview
              if clickedView == chipLabel → delegate?.didClickOnLabelView()
              (clicking label or closeButton falls through to super)
```

### Key Logic / Catch

- Uses `hitTest` to **distinguish** whether the chip label specifically was clicked vs. other parts of the view.
- The `closeButton` (NSButton) handles its own `action/target` independently — the delegate is only for the label chip area.
- Click fires on `mouseDown`, so there is no cancel-on-drag behavior.

---

## Summary Table

| Component | Fires On | Drag Guard | Hover | Delegate/Closure | Notes |
|---|---|---|---|---|---|
| **ZLabelView** | `mouseUp` | ✅ `dragFlag` | ❌ (arrow cursor set) | `ZLabelDelegate` | Drag suppresses click |
| **ZButton** | NSButton native | ❌ | ✅ delegate | `ZButtonDelegate` | Hover-only delegate |
| **ZCButton** | `sendAction` | ❌ | ✅ closures | Closures | Both actionBlock + target-action |
| **ZImageButton** | NSButton native | ❌ | ✅ closures + local monitor | Closures | Local event monitor on mouseDown |
| **ZCustomButton** | `sendAction` | ❌ | ✅ (cell redraw) | `actionBlock` | Cell-based state drawing |
| **ZDraggableButton** | NSButton native | ❌ | ✅ cursor change | None | Cursor only |
| **ZFilterButton** | NSButton native | ❌ | ✅ bg color | None | isSelected guards hover |
| **ZFormButton** | `sendAction` | ❌ | ✅ bg color | `actionBlock` | Image shown/hidden on hover |
| **ZHoverButton** | `sendAction` | ❌ | ✅ bg color | `actionBlock` | Same as ZFormButton + supportsDynamicWidth |
| **ZToggleButton** | `mouseDown` | ❌ | ✅ closures | `action` closure | Fires on mouseDown (no cancel) |
| **ToggleButton** | Overlay ZCButton | ❌ | ❌ | `actionBlock` | Invisible overlay button |
| **ZCheckbox** | `mouseUp` | ✅ bounds check | ❌ | `actionCallback` | mouseDown swallowed |
| **ZRadioButton** | `mouseDown` | ❌ | ❌ | `action` closure | Potential double-fire via overlay |
| **ZBadgeView** | `mouseUp` | ❌ | ❌ | `actionBlock` | Propagates to parent NSTableView |
| **ZSegment** | `mouseUp` | ❌ | ❌ | delegate → `actionBlock` | Fileprivate, managed by ZSegmentControl |
| **ZOverflowButton** | `mouseDown` | ❌ | ✅ bg color | `ZOverflowButtonDelegate` | Two fire paths (wrapper + inner button) |
| **ZLabelChipView** | `mouseDown` | ❌ | ❌ | `ZLabelChipViewDelegate` | hitTest distinguishes chip label |
