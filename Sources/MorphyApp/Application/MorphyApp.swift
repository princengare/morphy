import AppKit
import SwiftUI

@main
struct MorphyDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        _appState = StateObject(wrappedValue: AppState(environment: .live()))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appState)
        } label: {
            Image(nsImage: AppImages.monochromeLogo)
                .renderingMode(.template)
                .interpolation(.none)
                .accessibilityLabel("morphy")
        }
        .menuBarExtraStyle(.window)

        WindowGroup("morphy", id: "home") {
            RootPixelAppView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 720)
        }
        .defaultSize(width: 760, height: 760)
    }
}
