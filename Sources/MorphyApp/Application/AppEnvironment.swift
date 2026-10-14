import Foundation
import MorphyCore

struct AppEnvironment {
    let converter: any ImageConverting
    let historyStore: any HistoryStoring
    let webPInspector: any WebPCapabilityInspecting
    var preferencesStore: AppPreferencesStore? = nil
    var automaticallyMonitorFolder = false

    @MainActor
    static func live() -> AppEnvironment {
        let webPInspector = WebPCapabilityInspector()
        let historyStore: any HistoryStoring = (try? JSONHistoryStore.defaultStore()) ?? InMemoryHistoryStore()
        return AppEnvironment(
            converter: ImageConversionService(webPInspector: webPInspector),
            historyStore: historyStore,
            webPInspector: webPInspector,
            preferencesStore: AppPreferencesStore(),
            automaticallyMonitorFolder: true
        )
    }
}
