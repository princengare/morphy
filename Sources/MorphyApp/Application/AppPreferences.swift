import Foundation
import MorphyCore

struct AppPreferences: Codable {
    var monitoringEnabled = true
    var animateLeaves = true
    var notificationsEnabled = true
    var removeLocationInformation = false
    var selectedFormat: OutputFormat = .jpeg
    var qualityPreset: QualityPreset = .recommended
    var watchedFolderPath: String?
    var watchedFolderBookmark: Data?
}

@MainActor
final class AppPreferencesStore {
    private let defaults: UserDefaults
    private let key = "Morphy.preferences.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
