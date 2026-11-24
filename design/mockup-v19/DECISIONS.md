# Horion v19: making all-day events in the week

The user said: "i cant click into daily events and stuff to create events there".

What the app does now (`Sources/Horion/Views/DayHeaderView.swift`, `AllDayView`):
- A single click on empty space in the all-day lane calls `gridDismiss()`. Nothing else, so there is no double-click and no drag.
- The lane is exactly as tall as its chips, so a day whose lanes are full (Friday in the mockup: "Ferien" and "Office closed") has no empty spot at all.
- In a week with no all-day events the lane is 0 pt and only a line is left.
- The only way to make an all-day event is the month view (`createAllDay(on:)`, double-click a day).

Shots: `shots/busy.png`, `shots/empty.png`, `shots/day.png` (recommended picks), `shots/drag-create.png` (dragging Thu to Sun).

## Round 1 (open)
- Making an all-day event in the week: double-click or drag in the all-day lane (recommended), single click on a free spot, double-click the day's date, as now.
- Room to click when a day's lane is full: always one free row under the chips (recommended), a free row while the pointer is in the lane, only the gaps (as now).
- The all-day lane in a week with none: one empty row with the label (recommended), a 10 pt strip that opens on hover, hidden (as now).
- What a free spot shows on hover: soft fill with a + (recommended), a dashed "New all-day event" chip, nothing.

## Round 2
The user said: "i want that the events at the top are the same as in the the main editor events so i can at the side create an event there. also dont have this weird hover effect".

Locked:
- All-day chips end like timed blocks: every chip stops 2 pt + the create strip (`GridGeometry.createStrip`, 10 % of the day, 10 to 20 pt) before the edge of its last day. A multi-day chip runs on across days and leaves the strip only at its end. The side of every day is free to double-click or drag in, even on a full day; a new event made there opens a new row.
- What a free spot shows on hover: nothing (the round 1 fill with a + is gone).

Changed: "Room to click when a day's lane is full" now recommends "The side strip is enough, no extra row" (the spare row is the second option).
Still open: making an all-day event (double-click or drag recommended), room when full, the lane in a week with none.

Shot: `shots/round2-strip-create.png` (a new event made in Friday's strip).

## Build notes for the recommended picks (not built yet)
- `AllDayView.chipRect`: width `span * dw - 6 - GridGeometry.createStrip(dw - 1)`, so chips match `GridGeometry.rect`.
- `AllDayView`: in the `SpatialTapGesture`, a double-click (`clickCount == 2`) on a free spot calls `createAllDay(on:)` for that day; add a `DragGesture` across days for multi-day drafts (same draft flow as `GridInteraction`: dashed chip, panel in edit, Return saves, Esc discards).
- Height: unchanged when there are chips (the strip is the room); `contentHeight(rows: 1)` (30 pt) when there are none, instead of 0.
- Hover: no hover state on free spots.

## Round 3 (locked, 24 Nov 2026)
Picks: "single click on free spot AND this" (the date) and "but actually just one click on the date should be enough".
- Making an all-day event in the week: one click on a free spot in the all-day lane (a gap or the create strip) or on the day's date. The date no longer opens day view.
- Room when a day's lane is full: the side strip is enough, no extra row.
- The lane in a week with none: one empty row (30 pt) with the "all-day" label.
- Locked in round 2: chips end before the create strip; no hover on free spots.

Built: `DayHeaderView.swift` (`DayHeaderView` click → `createAllDay(on:)`; `AllDayView` empty click → `createAllDay(on:)`, one row when empty, `chipRect` minus `GridGeometry.createStrip`), `TimeGridView.swift` (the extra line for an empty lane is gone, the lane draws its own edge).
Nothing is open.
