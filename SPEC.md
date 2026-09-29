# Calendr — spec

A native macOS SwiftUI app that copies Notion Calendar 1:1 (dark appearance first). Reference screenshots are in `design/reference/` and are the visual truth. When this spec and a screenshot disagree, the screenshot wins.

Owner: Luis. Priorities, in order: 1) it works, 2) it is fast, 3) it looks exactly like Notion Calendar, 4) UX is thought through (keyboard-first, every action reachable from mouse and keyboard). **No animations anywhere** (no `withAnimation`, no implicit transitions; disable with `.transaction { $0.animation = nil }` at roots, `NSAnimationContext` duration 0 for window/panel work).

## Stack

- Swift 6 toolchain, Swift Package Manager, macOS 15+ deployment target. No Xcode project, no third-party packages.
- `Package.swift` with:
  - `CalendrKit` library: Foundation-only models and pure logic (event model, week/day math, overlap layout, all-day lane packing, command registry + fuzzy filter, natural-language "go to date" parser, upcoming-events grouping for the menu bar, search, recurrence description text, duration formatting). All logic lives here first, with tests.
  - `Calendr` executable: SwiftUI + AppKit shell, EventKit store, views. Views are thin bindings over an `@Observable` app model.
  - `CalendrKitTests`: Swift Testing (`import Testing`) tests. Add tests for named failures with observable results, not tests that restate implementation.
- `scripts/build-app.sh`: `swift build -c release`, assemble `build/Calendr.app` (Info.plist with `NSCalendarsFullAccessUsageDescription`, `NSContactsUsageDescription` not needed, bundle id `com.luiskisters.calendr`, `LSApplicationCategoryType` productivity), ad-hoc `codesign --force --deep -s -`.
- `scripts/verify.sh`: `swift build`, `swift test`, build-app, then the snapshot run (below). Must pass before any step is called done.

## Data

- `CalendarStore` protocol in the app target with two implementations:
  - `EventKitStore`: real macOS calendars (Google accounts added in System Settings show up here). Reads calendars grouped by source/account, events in a date range, creates/updates/deletes events, handles authorization (`requestFullAccessToEvents`). Listen to `EKEventStoreChanged` and refresh.
  - `DemoStore`: in-memory, seeded from the week in `design/reference/1-week-view.png` (Mon Sep 28 – Sun Oct 4 2026, same titles, times, calendars, colors, all-day events, tasks like "[P1] Daily stretch nehmen", recurring school classes, the declined/dashed "Bouldern" event, etc.). Accounts: `alex.rivera@example.com` (Personal default, Family, Tasks, School Board, Feiertage in Deutschland, Holidays in Germany, Ferien Berlin), `alex.work@example.com` (one visible calendar + three hidden), `alex@northwind.example.com`. Teammates from `3-teammate-picker.png` each with a handful of events that week.
- Launch args: `--demo` uses DemoStore (always used by tests, snapshots, walkthrough). `--now "2026-09-29T02:32"` pins the clock (default for demo). Without `--demo` the app uses EventKit and falls back to showing a clear "Grant calendar access" empty state.
- Load only the visible range (+/- one week prefetch). Compute layout once per range change in the model, never inside `body`.

## Surfaces (all must work)

1. **Main window** (min 1100x700, default ~1440x900, dark, hidden title bar, traffic lights inline with sidebar top like the screenshot).
   - **Left sidebar** (toggle with `` ` ``): sidebar/search/compose icons row; mini month calendar (Mo–Su, today red filled circle, current visible week highlighted as a rounded band, other-month days dimmed, up/down chevrons change month, click a day navigates); "Scheduling" row with eye icon; "Meet with…" field (typing filters teammates, choosing overlays their calendar); accounts with calendar rows (colored rounded-square checkbox, name, "Default" tag on default; click toggles visibility; hidden rows dimmed with eye.slash); "Add calendar account" (opens System Settings > Internet Accounts); "Add Notion database" and "Notion" rows as in screenshot (static, show a small "Not connected" popover).
   - **Toolbar** (top right of the center area): avatar circle, view menu button ("Week ⌄" with Day / Week / Month / custom 2-7 days), "Today" button, prev/next chevrons.
   - **Header**: big "September 2026" title; timezone label "GMT+2" with "+" to add a second tz; day headers "Mon 28", today as "Tue" + red rounded badge "29"; past days dimmed.
   - **All-day area**: collapse toggle (chevron/x at left), multi-day events span columns in lanes, packed without gaps, max visible lanes with "+N" when collapsed. Colors per calendar. Tasks render as the dashed/pill style from the screenshot.
   - **Time grid**: 24h, hour labels "05:00" style, 53pt-ish per hour like the screenshot, scrolls to ~working hours on open, past-time dimming, red current-time line with dot on today's column. Events: calendar-tinted fill with 3pt leading colored bar, title bold, time range below in dimmer text; short events (<30 min) single-line "Title 07:30" pill; overlapping events laid out side by side with Notion's cascading overlap (later event offset and on top); declined events strikethrough with dashed red outline; tentative/tasks with pill capsule style; past events dimmed.
   - **Interactions**: click empty slot selects; drag on empty grid creates an event (15-min snap) and opens it in the inspector with title focused; drag event body moves (across days), drag bottom edge resizes; click event selects and opens inspector; double-click opens + focuses title; Delete/Backspace deletes selected (recurring: ask "This event / All events"); Esc deselects; ⌘Z undo last create/move/resize/delete.
   - **Month view**: grid of weeks with event chips; **Day view**: single column. Day/Week/Month via `D`/`W`/`M`.
2. **Right panel** (toggle with ⌘/ or the panel icon at top right):
   - Default: "Search events" field at top; "Useful shortcuts" list exactly as screenshot 1 (Command menu ⌘K, Menu bar calendar control⌘K, Toggle sidebar `, Show teammate calendar P, Go to date ., All keyboard shortcuts ?).
   - Search: typing filters events across a wide range (±1 year for EventKit, all for demo), results list grouped by date, Enter/click navigates to that week and selects the event.
   - **Event inspector** (screenshot 2): "Event ⌄" header with "…" menu (Duplicate, Delete, Copy details); editable title; start time → end time + duration ("1h 40min"); date; All-day toggle; timezone row "GMT+2 Berlin"; recurrence row ("Every week on Wed until …") with prev/next occurrence chevrons; Participants (add by typing email); Conferencing; "Add AI meeting notes" (static); Location (multi-line, clickable opens Maps); "Add links and attachments"; Description editor; calendar picker (color + name); Busy/Free and visibility pickers; Reminders ("1min before"). Edits write through to the store immediately.
3. **Command menu** (⌘K, screenshot 4): centered floating panel over a dimmed window, search field "Type a command…", sections Calendar (Create event… C, Meet with… F, Show teammate calendar… P, Create recurring scheduling link…, Create one-off scheduling link… S, Add Notion database… O) and Navigation (Go to date… ., Go to today T, Left-align today in view ⌥T, Next period, Previous period, Switch to Day/Week/Month, Toggle sidebar, Toggle right panel, Settings), each with shortcut chips right-aligned; fuzzy filter; ↑↓ navigate, Enter select, Esc close; footer "⇅ Navigate ↩ Select esc Close". Scheduling-link commands copy a placeholder link and show a toast.
4. **Show teammate calendar** (P, screenshot 3): same panel style, "Show teammate calendar…" list "Name email", filter, selecting overlays that person's events in the grid (striped/translucent style, distinct), shown as removable chip in sidebar under a "Teammates" heading.
5. **Go to date** (`.`): same panel, natural input ("oct 12", "12.10.", "next friday", "tomorrow", "2026-12-24"), live preview line, Enter navigates.
6. **Keyboard**: all single-key shortcuts only fire when no text field is focused. `T` today, `⌥T` left-align today, `J`/`→` next period, `K`/`←` previous, `C` create at next free half-hour on selected/today, `D/W/M`, `P`, `F`, `.`, `?` shows all shortcuts sheet, `` ` `` sidebar, ⌘K command menu, ⌃⌘K menu bar calendar, ⌘1 main window, ⌘, settings.
7. **Menu bar calendar** (screenshot 5): `MenuBarExtra` (window style) whose label is next event "Meal Prep · in 4h 58m" with a rounded capsule look (updates every minute). Popover: "Upcoming in 4h 58min" header with next event row; "Start transcription" row (static); then Today / Tomorrow / weekday-date sections listing "HH:mm · Title" with a calendar-colored vertical bar (striped bar for tentative); footer "Notion Calendar ⌘1" (here "Open Calendr ⌘1") and "Settings… ⌘,". Clicking an event opens main window at that event.
8. **Settings** (⌘,): appearance (Dark/Light/System), week start (Mon default), default event duration, show declined events, time format 24h default, first visible hour, default calendar.

## Performance budget

- Cold launch to interactive under 500 ms in demo mode; week navigation under 16 ms per frame (no hitch) with 300 events visible.
- Time grid: draw hour lines/labels with a single `Canvas`; events as lightweight positioned views (no nested GeometryReaders per event); `LazyVStack`/fixed frames; `Equatable` event views; no `AnyView` in hot paths.
- Model is `@Observable @MainActor`; derived data (week layout, all-day lanes, upcoming list) cached and invalidated on range/store change only.

## Verification (inspired by NoteTakr)

Each behaviour has one owner layer:
- `CalendrKit` + `swift test`: all pure logic.
- **Snapshot states**: the app supports `--snapshot <state> --out <png>` which renders the main window (or panel/popover) in a named state via `ImageRenderer`/`NSView.cacheDisplay` offscreen and exits. States listed in `design/states.json` (week, week-selected-event/inspector, command-menu, teammate-picker, teammate-overlay, go-to-date, search-results, month, day, menubar-popover, sidebar-hidden, all-day-collapsed, create-drag, shortcuts-sheet, settings, light-week). `scripts/snapshots.sh` renders all into `artifacts/snapshots/`. Compare each against the matching `design/reference/*.png` and the HTML mockup (`design/mockup/`) by eye; every visible difference to the reference is a bug.
- **Walkthrough driver**: `--walkthrough --record <mp4>` runs a scripted, real-time tour of every feature through the same model actions the UI uses (keyboard shortcuts are dispatched as real `NSEvent`s into the window), captures the window each step (plus the menu bar popover content hosted in a window) into an H.264 mp4 with `AVAssetWriter`, and asserts the expected state after each step (exit non-zero on failure). This is both the E2E test and the deliverable video.
