import Foundation

enum AppearanceSetting: String, Codable, CaseIterable, Identifiable {
    case dark = "Dark", light = "Light", system = "System"
    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearanceSetting = .dark
    var weekStartsOnMonday = true
    var defaultDurationMinutes = 60
    var showDeclined = true
    var use24h = true
    var firstVisibleHour = 5
    var defaultCalendarID: String?

    static let key = "calendr.settings.v1"
    static func load() -> AppSettings {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(AppSettings.self, from: d) else { return AppSettings() }
        return s
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}
