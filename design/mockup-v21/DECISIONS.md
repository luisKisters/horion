# Horion v21 decisions
Mockup: `design/mockup-v21/index.html` (designr). The picker shows the same state. Base: the panel on branch `t3/panel-pickers`, checked against `Horion --snapshot v4-event`, `picker-zone` and the other `picker-*` states.
## Round 1 (locked)
Brief: the pickers missing from the event panel. Each must work by mouse and keyboard inside the v20 panel model.

| Decision | Pick |
| --- | --- |
| Where the pickers open | Left of the panel, over the grid |
| The end time list | Time, then the length (20:30 · 1 h 30) |
| Steps in the time lists | Every 15 min |
| When the time list and mini month open | As soon as the field has focus |
| ← → in the date field | Always move days while the mini month is open (changed after use, see below) |
| Where the time zone list opens | Inside the panel width, names cut |
| What the zone button says | Always the zone (GMT+2 Berlin) |
| Custom repeat | Rows with ‹ › |
| How a custom repeat ends | Never, or in 1, 2, 3 … months |
| A new rule on a repeating event | Asks: all events, or this and following |
| Participants on a macOS Calendar event | A card instead of the field |
## Changed after use (in the app)
- ← → in the date field: the caret moving before ↑/↓ felt wrong. Now ← → always move days while the mini month is open; Esc closes it to move the caret (the `always` option).
- Every panel menu opens left of the panel, not only the pickers: reminders, availability, visibility, call, maps, places and the send menus too.
- The time lists hug their rows: start 80 pt, end 136 pt. The end list shows the length on the right, short ("1 h 30").
## Locked in v20
| Element | Pick |
| --- | --- |
| Moving through the panel | Flat Tab: every control, top to bottom |
| Arriving in a text field by keyboard | Selects all |
| Return in a one-line field | Saves and moves on |
| Tab past the last control | Wraps to the top |
| Jump letters (hold ⌥) | On |
## Fixed without a decision
Round 1:
- Typing “930” in a time field did not read as 09:30 (lab version). Fixed in the mockup. The app parses it in `PanelText`.
## Alignment check
Press G (or "Alignment guides" in the picker).
- Green line: a left edge that 3 or more items share.
- Blue line: a shared right edge.
- Red box: an item 1 to 5 px off a shared line, with the offset.

All 7 scenes show 0 red boxes, and so do the other options (zone inside the panel and as a sheet, one-sentence repeat, date/count end, the guest card, length first, times only). Marked `data-centred` (not left edges): grey zone names after the city, key hints, the mini-month ‹ ›, the custom-repeat values and steppers, the search key cap, the length next to the times.
