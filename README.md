# Calendr

A native macOS SwiftUI calendar that copies Notion Calendar 1:1 (dark appearance first). Week, day and month views, a keyboard-first command menu, an event inspector with write-through edits, teammate overlays, a menu bar calendar, and two stores: your real Google / iCloud / local calendars through EventKit, or seeded demo data.

No animations anywhere. No third-party packages. SwiftPM only.

## Run it

```sh
scripts/build-app.sh && open build/Calendr.app                # real calendars (asks for calendar access)
open build/Calendr.app --args --demo                          # demo data, clock pinned to Tue Sep 29 2026 02:32
open build/Calendr.app --args --demo --now "2026-10-12T09:00" # demo data with another pinned time
```

`scripts/build-app.sh` builds release, assembles `build/Calendr.app` (bundle id `com.luiskisters.calendr`, calendar usage descriptions) and ad-hoc signs it (`codesign -s -`).

### Showing your Google and Apple calendars

Calendr reads calendars through EventKit, so anything macOS knows about shows up, grouped by account in the sidebar:

- **Google**: System Settings > Internet Accounts > Add Account > Google, sign in, keep "Calendars" on. The account appears under its gmail address with each calendar in its Google color.
- **iCloud / Exchange / CalDAV**: same place.
- **On My Mac**: calendars created locally in Calendar.app.

Then launch Calendr and press "Allow access". Cmd R asks macOS to re-sync remote sources; edits are written back through the account (recurring events save with "this event" or "this and following"). Read-only calendars (holidays, subscribed, shared read-only) show no edit affordances and cannot be dragged. Attendees are shown but cannot be edited: EventKit has no API to add them. Direct Google Calendar API access (OAuth) would allow attendee editing and Meet links; it is out of scope because it needs a provisioned client ID.

## Shortcuts

Single keys only fire when no text field is focused.

| Key | Action | Key | Action |
|---|---|---|---|
| `T` | Go to today | `C` | Create event at next free half hour |
| `Option T` | Left-align today in view | `P` | Show teammate calendar |
| `J` or `Right` | Next period | `F` | Meet with... (sidebar field) |
| `K` or `Left` | Previous period | `.` | Go to date ("oct 12", "12.10.", "next friday", "2026-12-24") |
| `D` `W` `M` | Day / Week / Month | `?` | All keyboard shortcuts |
| `` ` `` | Toggle sidebar | `Delete` | Delete selected event (recurring: this / all) |
| `Cmd /` | Toggle right panel | `Esc` | Deselect / close |
| `Cmd K` | Command menu | `Cmd Z` | Undo create / move / resize / delete |
| `Ctrl Cmd K` | Open the menu bar calendar | `Cmd F` | Search events |
| `Cmd 1` | Main window | `Cmd R` | Refresh calendars |
| `Cmd ,` | Settings | | |

Mouse: click an empty slot to select it, drag on the grid to create (15 minute snap), drag an event to move it across days, drag its bottom edge to resize, double-click to edit the title.

## How it is built

```
Sources/CalendrKit   Foundation-only logic: models, week math (Monday start), overlap + all-day layout, go-to-date parser,
                     command registry + fuzzy filter, upcoming grouping, duration/recurrence text, search, shortcut
                     resolver, EventKit mapping decisions. Swift Testing tests in Tests/CalendrKitTests.
Sources/Calendr      SwiftUI + AppKit shell. AppModel (@Observable @MainActor) owns state and caches layouts;
                     views are thin bindings. Stores/ has CalendarStore, EventKitStore, DemoStore.
  Views/             Sidebar, toolbar, grid, inspector, palettes, menu bar. The event grid, the mini calendar and the
                     hour lines are Canvas/CoreGraphics; everything else is native SwiftUI (List-free, Menu, Toggle,
                     Picker, TextField, MenuBarExtra).
  Headless/          --snapshot, --walkthrough, --perf drivers (offscreen window, video writer).
Tests/CalendrTests   App-level tests (model, gestures entry points, demo data vs the reference screenshot).
design/              reference screenshots, the HTML mockup + TOKENS.md, states.json.
```

AppKit is used only where SwiftUI cannot: window chrome, the key event monitor, offscreen rendering, video writing, opening the menu bar item.

## Verify

```sh
scripts/verify.sh          # grep gates, build, tests, app bundle, snapshots, walkthrough video, perf, launch time
scripts/verify.sh --fast   # skips walkthrough video and perf
```

- **Unit tests**: `swift test` (CalendrKit logic and app model).
- **Snapshots**: `scripts/snapshots.sh` renders every state in `design/states.json` offscreen into `artifacts/snapshots/`; `scripts/compare-all.sh` writes mockup | snapshot | diff images to `artifacts/compare/`. Every visible difference to the reference is a bug.
- **Walkthrough / E2E**: `Calendr --walkthrough --record artifacts/walkthrough.mp4` tours every feature (about 100 s, 1440x900, 30 fps, captions drawn into the frame), with 70+ assertions; exit code is non-zero on any failure. Keyboard shortcuts and typing are real `NSEvent`s dispatched through `NSApp.sendEvent`. Grid pointer gestures call `AppModel.gridMouseDown/Dragged/Up`, the exact functions the SwiftUI drag gesture forwards to, because synthesized mouse events cannot reach SwiftUI while the process cannot become the active app (unattended or locked session). Pickers and toggles in the inspector call the same `updateSelected` setter their bindings call.
- **Performance**: `Calendr --perf` navigates 50 weeks forward and 50 back with 300+ events per visible week and prints p50/p95 milliseconds per navigation (model reload + SwiftUI update + layout + draw) and cold launch. `Calendr --demo --print-launch` prints launch-to-window time of the real app.

Launch flags: `--demo`, `--now <ISO time>`, `--snapshot <state> --out <png> [--size WxH]`, `--walkthrough [--record <mp4>]`, `--perf`, `--print-launch`.

## Known gaps

- Screen capture of the running app needs Screen Recording permission (or an unlocked session), so evidence for the bundled app is `scripts/window-id.swift` plus the window list, not a screenshot; the offscreen renderer produces all pixel evidence.
- Notion database and Notion rows, "Start transcription", "Add AI meeting notes" and "Get Calendr to go" are static (a "not connected" popover or a toast), as in the spec.
- All-day events cannot be dragged in the grid (use the inspector); recurrence rules cannot be edited, only shown and stepped through.
- Editing a recurring event from the inspector affects that occurrence; deleting asks this / all.
- Participants can be added only in the demo store; EventKit exposes attendees read-only.
- Teammates for a real account are derived from attendees of your events; there is no directory.
- Light appearance is implemented from the mockup tokens but only the week and month views were visually reviewed.
- Undo history is per launch; after an EventKit delete + undo the restored event gets a new identifier.
