import SwiftUI
import CalendrKit

struct OverlayHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            if let o = model.overlay {
                Theme.overlay.ignoresSafeArea().onTapGesture { model.closeOverlay() }
                switch o {
                case .command: CommandPalette().padding(.top, 88)
                case .teammate: TeammatePalette().padding(.top, 88)
                case .goToDate: GoToDatePalette().padding(.top, 88)
                case .shortcuts: ShortcutsSheet().padding(.top, 60)
                case .settings: SettingsSheet().padding(.top, 110)
                case .deleteRecurring(let id): DeleteRecurringDialog(eventID: id).padding(.top, 200)
                }
            }
            if let t = model.toast {
                VStack { Spacer(); Text(t).font(.ui(13)).foregroundStyle(Theme.t1)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.pal))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.palBorder))
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                    .padding(.bottom, 64) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct PaletteFrame<Content: View>: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = 680
    @FocusState private var focused: Bool
    let onSubmit: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SFIcon(name: "magnifyingglass", size: 16).frame(width: 19).padding(.leading, 18).padding(.trailing, 11)
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color.dyn("#5f5f5f", "#a5a5a5")))
                    .textFieldStyle(.plain).font(.ui(16)).foregroundStyle(Theme.t1)
                    .focused($focused).onSubmit(onSubmit)
            }.frame(height: 51)
            content
            PaletteFooter()
        }
        .frame(width: width)
        .frame(maxHeight: 488)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.pal))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.palBorder))
        .shadow(color: .black.opacity(0.55), radius: 35, y: 24)
        .onAppear { focused = true }
    }
}

struct PaletteFooter: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) { SFIcon(name: "arrow.up.arrow.down", size: 12, color: Theme.palFootText); Text("Navigate") }
            HStack(spacing: 5) { SFIcon(name: "return", size: 12, color: Theme.palFootText); Text("Select") }
            HStack(spacing: 5) {
                Text("esc").padding(.horizontal, 5).frame(height: 17).background(RoundedRectangle(cornerRadius: 4).fill(Theme.chip))
                Text("Close")
            }
            Spacer()
        }
        .font(.ui(13)).foregroundStyle(Theme.palFootText)
        .padding(.horizontal, 12).frame(height: 32)
        .background(Theme.palFoot)
        .overlay(alignment: .top) { Rectangle().fill(Theme.palBorder).frame(height: 1) }
    }
}

struct PaletteRow<Label: View, Trailing: View>: View {
    let selected: Bool
    let action: () -> Void
    let label: Label
    let trailing: Trailing
    var body: some View {
        Button(action: action) {
            HStack {
                label
                Spacer(minLength: 8)
                trailing
            }
            .padding(.leading, 11).padding(.trailing, 10)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.palSel : Color.clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        let sections = model.commandSections
        let flat = CommandRegistry.flat(sections)
        PaletteFrame(placeholder: "Type a command\u{2026}", text: $m.commandQuery, onSubmit: {
            if !flat.isEmpty { model.perform(flat[min(model.commandIndex, flat.count - 1)].id) }
        }) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if sections.isEmpty {
                            Text("No commands found").font(.ui(12.5)).foregroundStyle(Theme.t2).padding(.horizontal, 11).padding(.top, 8).frame(height: 32)
                        }
                        ForEach(Array(sections.enumerated()), id: \.element.id) { si, sec in
                            CommandSectionView(section: sec, first: si == 0, flat: flat)
                        }
                    }.padding(.horizontal, 8).padding(.top, 5).padding(.bottom, 6)
                }
                .onChange(of: model.commandIndex) { _, i in proxy.scrollTo(i) }
            }
        }
    }
}

struct CommandSectionView: View {
    @Environment(AppModel.self) private var model
    let section: CommandSection
    let first: Bool
    let flat: [Command]
    var body: some View {
        Text(section.title).font(.ui(12.5)).foregroundStyle(Color.dyn("#828282", "#8a8a8a")).padding(.horizontal, 11)
            .frame(height: 24, alignment: .leading).padding(.top, first ? 4 : 8)
        ForEach(section.commands) { c in
            let idx = flat.firstIndex(where: { $0.id == c.id }) ?? 0
            CommandRowView(c: c, selected: idx == model.commandIndex).id(idx)
        }
    }
}

struct CommandRowView: View {
    @Environment(AppModel.self) private var model
    let c: Command
    let selected: Bool
    var body: some View {
        PaletteRow(selected: selected, action: { model.perform(c.id) },
                   label: Text(c.title).font(.ui(14.5)).foregroundStyle(Color.dyn("#d7d7d7", "#2a2a2a")),
                   trailing: HStack(spacing: 4) { ForEach(c.chips, id: \.self) { KbdChip(text: $0 == "command" ? "\u{2318}" : $0, palette: true) } })
    }
}

struct TeammatePalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        let list = model.filteredTeammates(model.teammateQuery)
        PaletteFrame(placeholder: "Show teammate calendar\u{2026}", text: $m.teammateQuery, onSubmit: {
            if !list.isEmpty { model.showTeammate(list[min(model.teammateIndex, list.count - 1)]) }
        }) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if list.isEmpty {
                            Text(model.store.teammates.isEmpty ? "No teammates found in your calendars yet" : "No teammates found").font(.ui(12.5)).foregroundStyle(Theme.t2).padding(.horizontal, 11).frame(height: 32)
                        }
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                            PaletteRow(selected: i == model.teammateIndex, action: { model.showTeammate(t) },
                                       label: HStack(spacing: 5) {
                                    Text(t.name).font(.ui(14.5)).foregroundStyle(Color.dyn("#d4d4d4", "#2a2a2a"))
                                    Text(t.email).font(.ui(14.5)).foregroundStyle(Color.dyn("#828282", "#8a8a8a"))
                                }.lineLimit(1),
                                       trailing: Group { if model.shownTeammates.contains(t) { SFIcon(name: "checkmark", size: 12) } }).id(i)
                        }
                    }.padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 6)
                }
                .onChange(of: model.teammateIndex) { _, i in proxy.scrollTo(i) }
            }
        }
    }
}

struct GoToDatePalette: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        PaletteFrame(placeholder: "Go to date\u{2026}", text: $m.goToText, onSubmit: { model.submitGoToDate() }) {
            VStack(alignment: .leading, spacing: 0) {
                if model.goToText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Try \u{201C}oct 12\u{201D}, \u{201C}12.10.\u{201D}, \u{201C}next friday\u{201D}, \u{201C}tomorrow\u{201D} or \u{201C}2026-12-24\u{201D}").font(.ui(12.5)).foregroundStyle(Theme.t2).padding(.horizontal, 11).padding(.top, 6).padding(.bottom, 10)
                } else if let d = model.goToPreview {
                    Text("Preview").font(.ui(12.5)).foregroundStyle(Theme.t2).padding(.horizontal, 11).padding(.top, 6).padding(.bottom, 4)
                    PaletteRow(selected: true, action: { model.submitGoToDate() },
                               label: Text("Go to \(model.fmt.fullDate(d))").font(.ui(14.5)).foregroundStyle(Theme.t1),
                               trailing: KbdChip(text: "\u{21A9}", palette: true))
                    .padding(.horizontal, 8).padding(.bottom, 8)
                } else {
                    Text("No date found for \u{201C}\(model.goToText)\u{201D}").font(.ui(12.5)).foregroundStyle(Theme.t2).padding(.horizontal, 11).padding(.top, 6).padding(.bottom, 10)
                }
            }
        }
    }
}

struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let width: CGFloat
    var closable = true
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.ui(15, .semibold)).foregroundStyle(Theme.t1)
                Spacer()
                if closable { IconButton(name: "xmark", size: 12, box: 24) { model.closeOverlay() } }
            }
            .padding(.horizontal, 18).frame(height: 48)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.palBorder).frame(height: 1) }
            content
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.pal))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.palBorder))
        .shadow(color: .black.opacity(0.55), radius: 35, y: 24)
    }
}

struct ShortcutsSheet: View {
    static let groups: [(String, [(String, [String])])] = [
        ("Navigation", [("Go to today", ["T"]), ("Left-align today in view", ["option", "T"]), ("Next period", ["J", "or", "\u{2192}"]), ("Previous period", ["K", "or", "\u{2190}"]),
                        ("Go to date", ["."]), ("Day view", ["D"]), ("Week view", ["W"]), ("Month view", ["M"])]),
        ("Calendar", [("Create event", ["C"]), ("Meet with\u{2026}", ["F"]), ("Show teammate calendar", ["P"]), ("Scheduling link", ["S"]),
                      ("Add Notion database", ["O"]), ("Undo", ["\u{2318}", "Z"]), ("Delete event", ["\u{232B}"])]),
        ("Windows", [("Command menu", ["\u{2318}", "K"]), ("Menu bar calendar", ["control", "\u{2318}", "K"]), ("Main window", ["\u{2318}", "1"]), ("Settings", ["\u{2318}", ","]),
                     ("Toggle sidebar", ["`"]), ("Toggle right panel", ["\u{2318}", "/"]), ("Refresh calendars", ["\u{2318}", "R"]), ("All keyboard shortcuts", ["?"]), ("Deselect or close", ["esc"])]),
    ]
    var body: some View {
        SheetFrame(title: "Keyboard shortcuts", width: 640) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.groups, id: \.0) { g in
                        Text(g.0).font(.ui(12, .medium)).foregroundStyle(Theme.t2).padding(.top, 10).padding(.bottom, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 36), GridItem(.flexible())], spacing: 0) {
                            ForEach(g.1, id: \.0) { r in
                                HStack {
                                    Text(r.0).font(.ui(13)).foregroundStyle(Theme.t1)
                                    Spacer()
                                    HStack(spacing: 3) { ForEach(Array(r.1.enumerated()), id: \.offset) { _, k in
                                        if k == "or" { Text("or").font(.ui(12)).foregroundStyle(Theme.t2) } else { KbdChip(text: k, palette: true) } } }
                                }.frame(height: 27)
                            }
                        }
                    }
                }.padding(.horizontal, 18).padding(.bottom, 18)
            }.frame(maxHeight: 620)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var last = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack { Text(title).font(.ui(14)).foregroundStyle(Theme.t1); Spacer(); content }
            .padding(.horizontal, 18).frame(height: 44)
            .overlay(alignment: .bottom) { if !last { Rectangle().fill(Theme.sep).frame(height: 1) } }
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var m = model
        SheetFrame(title: "Settings", width: 560) {
            VStack(spacing: 0) {
                SettingsRow(title: "Appearance") {
                    Picker("", selection: $m.settings.appearance) { ForEach(AppearanceSetting.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 190)
                }
                SettingsRow(title: "Week starts on") {
                    Picker("", selection: $m.settings.weekStartsOnMonday) { Text("Monday").tag(true); Text("Sunday").tag(false) }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                SettingsRow(title: "Time format") {
                    Picker("", selection: $m.settings.use24h) { Text("24-hour").tag(true); Text("12-hour").tag(false) }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                }
                SettingsRow(title: "Default event duration") {
                    Picker("", selection: $m.settings.defaultDurationMinutes) { ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) } }
                        .labelsHidden().frame(width: 110)
                }
                SettingsRow(title: "First visible hour") {
                    Picker("", selection: $m.settings.firstVisibleHour) { ForEach(0..<13, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }
                        .labelsHidden().frame(width: 110)
                }
                SettingsRow(title: "Show declined events") {
                    Toggle("", isOn: $m.settings.showDeclined).toggleStyle(.switch).labelsHidden()
                }
                SettingsRow(title: "Default calendar", last: true) {
                    Picker("", selection: Binding(get: { model.settings.defaultCalendarID ?? model.store.defaultCalendarID ?? "" }, set: { model.settings.defaultCalendarID = $0 })) {
                        ForEach(model.store.allCalendars.filter(\.isWritable)) { Text($0.title).tag($0.id) }
                    }.labelsHidden().frame(width: 200)
                }
            }
        }
    }
}

struct DeleteRecurringDialog: View {
    @Environment(AppModel.self) private var model
    let eventID: String
    var body: some View {
        SheetFrame(title: "Delete recurring event", width: 380, closable: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("This event repeats. Which events should be deleted?").font(.ui(13)).foregroundStyle(Theme.t2).padding(.horizontal, 18).padding(.top, 16)
                HStack(spacing: 8) {
                    Spacer()
                    DialogButton(title: "Cancel") { model.closeOverlay() }
                    DialogButton(title: "This event") { if let e = model.event(id: eventID) { model.delete(e, span: .this) } }
                    DialogButton(title: "All events", primary: true) { if let e = model.event(id: eventID) { model.delete(e, span: .all) } }
                }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 18)
            }
        }
    }
}

struct DialogButton: View {
    let title: String
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.ui(13)).foregroundStyle(primary ? Color.white : Theme.t1).padding(.horizontal, 14).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(primary ? Theme.ring : Theme.btn))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(primary ? Theme.ring : Theme.btnBorder))
        }.buttonStyle(.plain)
    }
}
