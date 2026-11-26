# Horion v21 decisions
Mockup: `design/mockup-v21/index.html` (designr). The picker shows the same state. Base: the panel on branch `t3/panel-pickers`, checked against `Horion --snapshot v4-event`, `picker-zone` and the other `picker-*` states.
## Round 1 (open)
Brief: the pickers missing from the event panel. Each must work by mouse and keyboard inside the v20 panel model.

| Decision | Recommended (built) | Other options |
| --- | --- | --- |
| The end time list | Time, then the length (20:30 · 1 h 30) | Length first · Times only |
| Steps in the time lists | Every 15 min | Every 30 min |
| When the time list and mini month open | As soon as the field has focus | Only on a click or ↓ |
| ← → in the date field | Move days once ↑ or ↓ started picking | Always move days · Only move the caret |
| Where the time zone list opens | Wide, over the grid, right edge on the button | Inside the panel · Takes over the panel |
| What the zone button says | “Time zone”, then the city and its times | Offset and city · Always the zone |
| Custom repeat | Rows with ‹ › | One sentence |
| How a custom repeat ends | Never, or in 1, 2, 3 … months | Never, on a date, or after a count |
| A new rule on a repeating event | Changes the whole series | Asks: all events, or this and following |
| Participants on a macOS Calendar event | Field stays, one grey line says why | A card instead of the field · No field |
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
