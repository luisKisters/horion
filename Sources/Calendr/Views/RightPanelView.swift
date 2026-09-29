import SwiftUI
import CalendrKit

struct KbdChip: View {
    let text: String
    var palette = false
    var body: some View {
        Text(text).font(.ui(12)).foregroundStyle(palette ? Color.dyn("#909090", "#777777") : Theme.chipText)
            .padding(.horizontal, 4).frame(minWidth: 17, minHeight: palette ? 15 : 16)
            .background(RoundedRectangle(cornerRadius: 3).fill(palette ? Theme.palChip : Theme.chip))
    }
}

struct RightPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg
            if model.selectedEvent != nil {
                InspectorView()
                PanelToggle().frame(maxWidth: .infinity, maxHeight: 40, alignment: .topTrailing)
            } else {
                DefaultPanel()
            }
        }
        .frame(width: Theme.rightPanelWidth)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.border).frame(width: 1) }
    }
}

struct PanelToggle: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        IconButton(name: "sidebar.right", size: 15, box: 22) { model.toggleRightPanel() }.padding(.trailing, 15).padding(.top, 9)
    }
}

struct DefaultPanel: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var m = model
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SFIcon(name: "calendar.badge.magnifyingglass", size: 14, color: Theme.t3).frame(width: 18).padding(.leading, 15).padding(.trailing, 8)
                TextField("Search events", text: $m.searchText)
                    .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1)
                    .focused($searchFocused)
                    .onSubmit { if let e = model.searchGroups.first?.events.first { model.openSearchResult(e) } }
                if !model.searchText.isEmpty {
                    IconButton(name: "xmark.circle.fill", size: 12, box: 20) { model.searchText = "" }
                }
                Spacer(minLength: 0)
            }
            .frame(width: Theme.rightPanelWidth - 44, height: 40)
            .onChange(of: model.focusSearchTick) { _, _ in searchFocused = true }
            PanelToggle().frame(width: Theme.rightPanelWidth, height: 40, alignment: .topTrailing)

            if model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Useful shortcuts").font(.ui(14, .medium)).foregroundStyle(Theme.t1).frame(height: 20, alignment: .leading).padding(.bottom, 3)
                    ShortcutRow("Command menu", ["\u{2318}", "K"])
                    ShortcutRow("Menu bar calendar", ["control", "\u{2318}", "K"])
                    ShortcutRow("Toggle sidebar", ["`"])
                    ShortcutRow("Show teammate calendar", ["P"])
                    ShortcutRow("Go to date", ["."])
                    ShortcutRow("All keyboard shortcuts", ["?"])
                }
                .padding(.horizontal, 16).padding(.top, 78)
            } else {
                SearchResults().padding(.top, 52)
            }
        }
        .frame(width: Theme.rightPanelWidth, alignment: .topLeading)
    }
}

struct ShortcutRow: View {
    let title: String
    let keys: [String]
    @State private var hover = false
    init(_ t: String, _ k: [String]) { title = t; keys = k }
    var body: some View {
        HStack {
            Text(title).font(.ui(13)).foregroundStyle(hover ? Theme.t1 : Theme.t2)
            Spacer()
            HStack(spacing: 3) { ForEach(keys, id: \.self) { KbdChip(text: $0) } }
        }
        .frame(height: 24)
        .onHover { hover = $0 }
    }
}

struct SearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.searchGroups.isEmpty {
                    Text("No events match \u{201C}\(model.searchText)\u{201D}").font(.ui(13)).foregroundStyle(Theme.t2).padding(.horizontal, 16).padding(.vertical, 24)
                }
                ForEach(model.searchGroups) { g in
                    let today = model.math.isSameDay(g.day, model.now)
                    Text("\(model.fmt.weekdayShort(g.day)), \(model.fmt.monthDay(g.day))" + (today ? " \u{00B7} Today" : ""))
                        .font(.ui(12, .medium)).foregroundStyle(Theme.t2).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                    ForEach(g.events) { e in SearchRow(e: e) }
                }
            }.padding(.horizontal, 8)
        }
    }
}

struct SearchRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let e: CalendarEvent
    @State private var hover = false
    var body: some View {
        let pal = e.kind == .task ? Palettes.gray(scheme == .dark) : Palettes.palette(barHex: model.calendarColorHex(of: e), fillHex: nil, dark: scheme == .dark)
        Button { model.openSearchResult(e) } label: {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 2).fill(pal.bar).frame(width: 3, height: 16)
                Text(e.title).font(.ui(13)).foregroundStyle(Theme.t1).lineLimit(1)
                Spacer(minLength: 0)
                Text(e.isAllDay ? "All day" : model.fmt.time(e.start)).font(.mono(12)).foregroundStyle(Theme.t2)
            }
            .padding(.horizontal, 8).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Theme.hover : Color.clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}

// MARK: - Inspector

struct MiniToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? Theme.ring : Theme.t3).frame(width: 17, height: 10)
                Circle().fill(Color.white).frame(width: 8, height: 8).padding(1)
            }
        }.buttonStyle(.plain)
    }
}

struct InspectorRow<Content: View>: View {
    var icon: String?
    var muted = false
    @ViewBuilder var content: Content
    var body: some View {
        ZStack(alignment: .leading) {
            if let icon { SFIcon(name: icon, size: 14, color: muted ? Theme.t3 : Theme.t2).frame(width: 18).padding(.leading, 15) }
            content.padding(.leading, 41).padding(.trailing, 12)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var titleFocused: Bool

    var body: some View {
        if let e = model.selectedEvent {
            let writable = model.isWritable(e)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 6) {
                    Text("Event").font(.ui(14)).foregroundStyle(Theme.t1)
                    SFIcon(name: "chevron.down", size: 11, weight: .semibold)
                }.offset(x: 15, y: 72).frame(height: 32)
                EventMenu(e: e, writable: writable).frame(width: Theme.rightPanelWidth, alignment: .trailing).offset(y: 72)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("New event", text: Binding(get: { model.selectedEvent?.title ?? "" }, set: { v in model.updateSelected { $0.title = v } }))
                            .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1)
                            .focused($titleFocused)
                            .padding(.horizontal, 15).frame(height: 38)
                            .disabled(!writable)
                            .onChange(of: model.focusTitleTick) { _, _ in titleFocused = true }
                            .onSubmit { titleFocused = false }
                        Section1(e: e, writable: writable)
                        Section2(e: e, writable: writable)
                        Divider0()
                        InspectorRow(icon: "link", muted: true) { Text("Add links and attachments").font(.ui(14)).foregroundStyle(Theme.t3) }.padding(.vertical, 8)
                        Divider0()
                        Description(e: e, writable: writable)
                        Divider0()
                        Section3(e: e, writable: writable)
                    }
                    .font(.ui(14))
                }
                .padding(.top, 110)
                .frame(width: Theme.rightPanelWidth, alignment: .topLeading)
            }
            .frame(width: Theme.rightPanelWidth, height: nil, alignment: .topLeading)
            .onAppear { if model.focusTitleTick > 0 { titleFocused = true } }
        }
    }
}

struct Divider0: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

struct EventMenu: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        Menu {
            Button("Duplicate") { model.duplicateSelected() }
            Button("Copy details") { model.copySelectedDetails() }
            Divider()
            Button("Delete", role: .destructive) { model.requestDeleteSelected() }.disabled(!writable)
        } label: {
            SFIcon(name: "ellipsis", size: 14).frame(width: 32, height: 32).contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .padding(.trailing, 15)
    }
}

struct Section1: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    @State private var showDate = false
    @State private var startText = ""
    @State private var endText = ""

    var body: some View {
        let fmt = model.fmt
        VStack(alignment: .leading, spacing: 0) {
            InspectorRow(icon: "clock") {
                if e.isAllDay { Text("All day").font(.ui(14)).foregroundStyle(Theme.t2) }
                else {
                    HStack(spacing: 0) {
                        TimeField(minutes: model.math.minutesSinceMidnight(e.start), fmt: fmt, writable: writable) { m in
                            model.updateSelected { ev in
                                let dur = ev.end.timeIntervalSince(ev.start)
                                ev.start = model.math.date(on: ev.start, minutes: m); ev.end = ev.start.addingTimeInterval(dur)
                            }
                        }.frame(width: 75, alignment: .leading)
                        SFIcon(name: "arrow.right", size: 13).padding(.trailing, 26)
                        TimeField(minutes: model.math.minutesSinceMidnight(e.end), fmt: fmt, writable: writable) { m in
                            model.updateSelected { ev in
                                var end = model.math.date(on: ev.end, minutes: m)
                                if end <= ev.start { end = ev.start.addingTimeInterval(15 * 60) }
                                ev.end = end
                            }
                        }.frame(width: 50, alignment: .leading)
                        Text(DurationText.minutes(e.durationMinutes)).font(.mono(14)).foregroundStyle(Theme.t2).padding(.leading, 5)
                    }
                }
            }.padding(.leading, 0)
            InspectorRow {
                Button { if writable { showDate = true } } label: {
                    Text(fmt.inspectorDate(e.start)).font(.mono(14)).foregroundStyle(Theme.t1)
                }.buttonStyle(.plain)
                .popover(isPresented: $showDate) {
                    DatePicker("", selection: Binding(get: { e.start }, set: { d in
                        model.updateSelected { ev in
                            let delta = model.math.daysBetween(ev.start, d)
                            ev.start = model.math.addDays(ev.start, delta); ev.end = model.math.addDays(ev.end, delta)
                        }
                    }), displayedComponents: .date).datePickerStyle(.graphical).labelsHidden().padding(8)
                }
            }
            InspectorRow {
                Text("All-day").font(.ui(14)).foregroundStyle(Theme.t1)
            }
            .overlay(alignment: .leading) {
                Toggle("", isOn: Binding(get: { model.selectedEvent?.isAllDay ?? false }, set: { on in
                    model.updateSelected { ev in
                        ev.isAllDay = on
                        if on { ev.start = model.math.startOfDay(ev.start); ev.end = model.math.addDays(ev.start, 1) }
                        else { ev.start = model.math.date(on: ev.start, minutes: 9 * 60); ev.end = ev.start.addingTimeInterval(Double(model.settings.defaultDurationMinutes) * 60) }
                    }
                })).toggleStyle(MiniToggleStyle()).labelsHidden().padding(.leading, 15).disabled(!writable)
            }
            InspectorRow(icon: "globe") {
                HStack(spacing: 0) {
                    Text(fmt.gmtLabel(e.start) + " ").font(.ui(14)).foregroundStyle(Theme.t2)
                    Text(fmt.timeZoneCity()).font(.ui(14)).foregroundStyle(Theme.t1)
                }
            }
            InspectorRow(icon: "arrow.triangle.2.circlepath") {
                if let r = e.recurrence {
                    let t = RecurrenceDescriber.describe(r, start: e.start, fmt: fmt)
                    HStack(spacing: 0) {
                        (Text(t.lead).foregroundColor(Theme.t1) + Text(t.rest.isEmpty ? "" : " " + t.rest).foregroundColor(Theme.t2))
                            .font(.ui(14)).lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                } else if e.seriesID != nil {
                    Text("Repeats").font(.ui(14)).foregroundStyle(Theme.t1)
                } else {
                    Text("Does not repeat").font(.ui(14)).foregroundStyle(Theme.t2)
                }
            }
            .overlay(alignment: .trailing) {
                if e.isRecurring {
                    HStack(spacing: 0) {
                        IconButton(name: "chevron.left", size: 12, box: 32) { model.selectOccurrence(-1) }
                        IconButton(name: "chevron.right", size: 12, box: 32) { model.selectOccurrence(1) }
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Divider0() }
    }
}

struct TimeField: View {
    let minutes: Int
    let fmt: Fmt
    let writable: Bool
    let commit: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain).font(.mono(14)).foregroundStyle(Theme.t1)
            .focused($focused)
            .disabled(!writable)
            .onAppear { text = fmt.time(minutes: minutes) }
            .onChange(of: minutes) { _, m in if !focused { text = fmt.time(minutes: m) } }
            .onChange(of: focused) { _, f in if !f { apply() } }
            .onSubmit { apply() }
    }
    private func apply() {
        if let m = TimeParser.parse(text) { commit(m); text = fmt.time(minutes: m) } else { text = fmt.time(minutes: minutes) }
    }
}

struct Section2: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    @State private var newParticipant = ""
    @State private var conferencing = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorRow(icon: "person", muted: true) {
                TextField("Participants", text: $newParticipant)
                    .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1)
                    .disabled(!writable || !model.store.canEditParticipants)
                    .onSubmit {
                        let v = newParticipant.trimmingCharacters(in: .whitespaces)
                        guard !v.isEmpty else { return }
                        model.updateSelected { $0.participants.append(v) }; newParticipant = ""
                    }
            }
            ForEach(e.participants, id: \.self) { p in
                HStack(spacing: 6) {
                    Text(p).font(.ui(13)).foregroundStyle(Theme.t1).lineLimit(1)
                    Spacer()
                    if model.store.canEditParticipants && writable {
                        IconButton(name: "xmark", size: 9, box: 16) { model.updateSelected { $0.participants.removeAll { $0 == p } } }
                    }
                }.padding(.leading, 41).padding(.trailing, 12).frame(height: 24)
            }
            if !model.store.canEditParticipants && !e.participants.isEmpty {
                Text("Attendees are read-only (EventKit cannot edit them).").font(.ui(11)).foregroundStyle(Theme.t3).padding(.leading, 41).padding(.bottom, 4)
            }
            InspectorRow(icon: "video", muted: true) {
                TextField("Conferencing", text: Binding(get: { model.selectedEvent?.conferencing ?? "" }, set: { v in model.updateSelected { $0.conferencing = v } }))
                    .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1).disabled(!writable)
            }
            InspectorRow(icon: "waveform.and.mic", muted: true) { Text("Add AI meeting notes").font(.ui(14)).foregroundStyle(Theme.t3) }
            LocationRow(e: e, writable: writable)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider0() }
    }
}

struct LocationRow: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            Button { model.openInMaps(e.location) } label: {
                SFIcon(name: "mappin.and.ellipse", size: 14, color: e.location.isEmpty ? Theme.t3 : Theme.t2).frame(width: 18)
            }.buttonStyle(.plain).padding(.leading, 15).padding(.top, 7)
            TextField("Add location", text: Binding(get: { model.selectedEvent?.location ?? "" }, set: { v in model.updateSelected { $0.location = v } }), axis: .vertical)
                .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1).lineSpacing(0)
                .lineLimit(1...4).disabled(!writable)
                .padding(.leading, 41).padding(.trailing, 12).padding(.top, 7).padding(.bottom, 7)
        }
        .frame(minHeight: 32, alignment: .topLeading)
    }
}

struct Description: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        TextField("Add description", text: Binding(get: { model.selectedEvent?.notes ?? "" }, set: { v in model.updateSelected { $0.notes = v } }), axis: .vertical)
            .textFieldStyle(.plain).font(.ui(14)).foregroundStyle(Theme.t1).lineLimit(2...10).lineSpacing(2)
            .disabled(!writable)
            .padding(.horizontal, 15).padding(.top, 13).frame(minHeight: 82, alignment: .topLeading)
    }
}

struct Section3: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let writable: Bool
    var body: some View {
        let cal = model.calendarInfo(e.calendarID)
        VStack(alignment: .leading, spacing: 0) {
            Menu {
                ForEach(model.store.accounts) { a in
                    Section(a.name) {
                        ForEach(a.calendars.filter(\.isWritable)) { c in
                            Button(c.title) { model.updateSelected { $0.calendarID = c.id } }
                        }
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: cal?.colorHex ?? "#5c88e4")).frame(width: 18, height: 13).padding(.leading, 15).padding(.trailing, 8)
                    Text(cal?.title ?? "Calendar").font(.ui(14)).foregroundStyle(Theme.t1).lineLimit(1)
                    Spacer(minLength: 0)
                }.frame(height: 32).contentShape(Rectangle())
            }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).disabled(!writable)
            ZStack(alignment: .leading) {
                Menu {
                    Button("Busy") { model.updateSelected { $0.availability = .busy } }
                    Button("Free") { model.updateSelected { $0.availability = .free } }
                } label: { Text(e.availability == .busy ? "Busy" : "Free").font(.ui(14)).foregroundStyle(Theme.t1).contentShape(Rectangle()) }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().padding(.leading, 41).disabled(!writable)
                Menu {
                    Button("Default visibility") { model.updateSelected { $0.visibility = .standard } }
                    Button("Public") { model.updateSelected { $0.visibility = .public } }
                    Button("Private") { model.updateSelected { $0.visibility = .private } }
                } label: { Text(e.visibility == .standard ? "Default visibility" : e.visibility == .public ? "Public" : "Private").font(.ui(14)).foregroundStyle(Theme.t1).contentShape(Rectangle()) }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().padding(.leading, 139).disabled(!writable)
            }.frame(height: 32)
            InspectorRow(icon: "bell", muted: true) { Text("Reminders").font(.ui(14)).foregroundStyle(Theme.t3) }
            ZStack(alignment: .leading) {
                Menu {
                    ForEach([(nil, "None"), (0, "At time of event"), (1, "1min before"), (5, "5min before"), (10, "10min before"), (15, "15min before"), (30, "30min before"), (60, "1h before"), (1440, "1 day before")] as [(Int?, String)], id: \.1) { m, t in
                        Button(t) { model.updateSelected { $0.reminderMinutes = m } }
                    }
                } label: {
                    HStack(spacing: 0) {
                        if let m = e.reminderMinutes {
                            Text(m == 0 ? "At time" : DurationText.minutes(m)).font(.ui(14)).foregroundStyle(Theme.t1)
                            Text(m == 0 ? "" : " before").font(.ui(14)).foregroundStyle(Theme.t2)
                        } else { Text("None").font(.ui(14)).foregroundStyle(Theme.t3) }
                    }.contentShape(Rectangle())
                }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().padding(.leading, 41).disabled(!writable)
            }.frame(height: 32)
            if !writable {
                Text("This calendar is read-only.").font(.ui(11)).foregroundStyle(Theme.t3).padding(.leading, 15).padding(.vertical, 6)
            }
        }
        .padding(.vertical, 8).padding(.bottom, 40)
    }
}
