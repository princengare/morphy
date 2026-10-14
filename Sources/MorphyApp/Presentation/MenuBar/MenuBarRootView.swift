import AppKit
import MorphyCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    var changingInitiallyExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ChangingMenuSection(initiallyExpanded: changingInitiallyExpanded)
            menuAction("open morphy", symbol: "macwindow") {
                appState.navigate(.home)
                openWindow(id: "home")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider().padding(.vertical, 3)
            menuAction("quit morphy", symbol: "power") { NSApp.terminate(nil) }
        }
        .padding(10)
        .frame(width: 232)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func menuAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

struct ChangingMenuSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @State private var isPinned: Bool
    @State private var isSelectingOption = false

    init(initiallyExpanded: Bool = false) {
        _isPinned = State(initialValue: initiallyExpanded)
    }

    private var isExpanded: Bool { isHovered || isPinned || isSelectingOption }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isPinned.toggle() } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(appState.monitoringEnabled && !appState.monitoringNeedsAccess ? Color.green : .secondary)
                        .frame(width: 7, height: 7)
                    Text("changing")
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Color.primary.opacity(isExpanded ? 0.12 : 0.07), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("changing")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityHint("Show automatic conversion, format, and quality controls")
            .help(appState.statusText)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("automatic conversion", isOn: $appState.monitoringEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    if appState.monitoringNeedsAccess {
                        Button("allow folder access...") { appState.chooseWatchedFolder() }
                    }
                    Picker("convert to", selection: $appState.selectedFormat) {
                        ForEach(appState.availableFormats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("quality", selection: $appState.qualityPreset) {
                        ForEach(QualityPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!appState.selectedFormat.supportsLossyQuality)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onExitCommand { isPinned = false }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            isSelectingOption = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            isSelectingOption = false
        }
    }
}
