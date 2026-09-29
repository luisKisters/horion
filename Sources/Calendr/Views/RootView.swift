import SwiftUI
import AppKit
import CalendrKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.bg
            HStack(spacing: 0) {
                if model.sidebarVisible { SidebarView() }
                CenterView()
                if model.rightPanelVisible { RightPanelView() }
            }
            if !model.sidebarVisible {
                HStack(spacing: 0) {
                    IconButton(name: "sidebar.left", size: 15) { model.toggleSidebar() }.padding(.leading, 82)
                    Spacer()
                }.frame(maxHeight: .infinity, alignment: .top).padding(.top, 9)
            }
            GetCalendrPill()
            if model.authState != .authorized { AccessPrompt() }
            OverlayHost()
        }
        .ignoresSafeArea()
        .preferredColorScheme(model.settings.appearance == .dark ? .dark : model.settings.appearance == .light ? .light : nil)
        .transaction { $0.animation = nil }
        .font(.ui(13))
    }
}

struct GetCalendrPill: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack { Spacer(); HStack { Spacer()
            Button { model.showToast("Calendr is already on your Mac") } label: {
                Text("Get Calendr to go").font(.ui(13)).foregroundStyle(Theme.t1).padding(.horizontal, 14).frame(height: 29)
                    .background(Capsule().fill(Theme.getCal))
            }.buttonStyle(.plain).padding(.trailing, 16).padding(.bottom, 15)
        } }
    }
}

/// Shown in place of the calendar when EventKit access has not been granted.
struct AccessPrompt: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 12) {
            SFIcon(name: "calendar.badge.exclamationmark", size: 34, color: Theme.t2)
            Text("Grant calendar access").font(.ui(18, .semibold)).foregroundStyle(Theme.t1)
            Text(model.authState == .denied
                 ? "Calendr has no access to your calendars. Enable it in System Settings > Privacy & Security > Calendars."
                 : "Calendr shows your Google, iCloud and local calendars through macOS. Allow access to continue.")
                .font(.ui(13)).foregroundStyle(Theme.t2).multilineTextAlignment(.center).frame(width: 360)
            HStack(spacing: 8) {
                if model.authState == .notDetermined { DialogButton(title: "Allow access", primary: true) { model.requestAccess() } }
                else { DialogButton(title: "Open System Settings", primary: true) { model.openPrivacySettings() } }
                DialogButton(title: "Use demo data") { model.showToast("Relaunch with --demo to use demo data") }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.opacity(0.96))
    }
}
