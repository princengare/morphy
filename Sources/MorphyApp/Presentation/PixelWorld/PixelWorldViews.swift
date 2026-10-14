import AppKit
import MorphyCore
import SwiftUI

struct RootPixelAppView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            switch appState.route {
            case .home:
                HomePageView()
            case .export:
                ExportOptionsPageView()
            case .conversion:
                ConversionStatusPageView()
            case .history:
                HistoryPageView()
            case .settings:
                SettingsPageView()
            }
        }
    }
}

struct HomePageView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredSection: HomeNavigationSection?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                PixelPalette.forest.ignoresSafeArea()
                PixelTreeTrunk()
                    .frame(width: size.width * 0.25, height: size.height)

                ForEach(HomeNavigationSection.allCases) { section in
                    HomeNavigationBand(section: section, canvasSize: size,
                        isHovered: hoveredSection == section, animateLeaves: appState.animateLeaves,
                        reduceMotion: reduceMotion, onHoverChanged: { hovering in
                            if hovering { hoveredSection = section }
                            else if hoveredSection == section { hoveredSection = nil }
                        }) {
                            appState.navigate(section.route)
                        }
                        .frame(width: size.width, height: size.height * section.bandHeight)
                        .position(x: size.width / 2, y: size.height * section.bandCenter)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

}

enum HomeNavigationSection: String, CaseIterable, Identifiable {
    case export, history, settings

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var route: AppRoute {
        switch self {
        case .export: .export
        case .history: .history
        case .settings: .settings
        }
    }
    var icon: PixelIcon.Kind {
        switch self {
        case .export: .export
        case .history: .history
        case .settings: .settings
        }
    }
    var bandTop: CGFloat {
        switch self {
        case .export: 0
        case .history: 0.325
        case .settings: 0.615
        }
    }
    var bandBottom: CGFloat {
        switch self {
        case .export: 0.325
        case .history: 0.615
        case .settings: 1
        }
    }
    var bandHeight: CGFloat { bandBottom - bandTop }
    var bandCenter: CGFloat { (bandTop + bandBottom) / 2 }
    var leafCenter: CGFloat {
        switch self {
        case .export: 0.18
        case .history: 0.47
        case .settings: 0.76
        }
    }
    var iconCenter: CGFloat {
        switch self {
        case .export: 0.15
        case .history: 0.44
        case .settings: 0.75
        }
    }
    var iconScale: CGFloat {
        switch self {
        case .export: 0.19
        case .history: 0.22
        case .settings: 0.21
        }
    }
    var windRate: Double {
        switch self {
        case .export: 1.65
        case .history: 1.875
        case .settings: 2.1
        }
    }
    var windPhase: Double {
        switch self {
        case .export: 0.4
        case .history: 2.2
        case .settings: 4.1
        }
    }
}

struct HomeNavigationBand: View {
    let section: HomeNavigationSection
    let canvasSize: CGSize
    let isHovered: Bool
    let animateLeaves: Bool
    let reduceMotion: Bool
    let onHoverChanged: (Bool) -> Void
    let action: () -> Void
    @FocusState private var isFocused: Bool

    private var isHighlighted: Bool { isHovered || isFocused }

    var body: some View {
        let base = min(canvasSize.width, canvasSize.height)
        let leafWidth = base * 0.44
        let leafHeight = leafWidth * 9 / 14
        let leafPaused = reduceMotion || !animateLeaves || isHighlighted
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Color.clear
                TimelineView(.animation(minimumInterval: 1.0 / 18, paused: leafPaused)) { timeline in
                    PixelLeafSprite(isHighlighted: isHighlighted,
                        windElapsed: leafPaused ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                        windRate: section.windRate, windPhase: section.windPhase)
                }
                .frame(width: leafWidth, height: leafHeight)
                .position(x: canvasSize.width * 0.25 - 10 + leafWidth / 2,
                    y: canvasSize.height * (section.leafCenter - section.bandTop))

                HoverAnimatedPixelIcon(kind: section.icon, isActive: isHighlighted, reduceMotion: reduceMotion)
                    .frame(width: base * section.iconScale, height: base * section.iconScale)
                    .position(x: canvasSize.width * 0.82,
                        y: canvasSize.height * (section.iconCenter - section.bandTop))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover(perform: onHoverChanged)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.title)
        .help(section.title)
    }
}

struct ExportOptionsPageView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PixelFeatureShell {
            VStack(alignment: .leading, spacing: 18) {
                PixelTitle("EXPORT")

                PixelChoiceGroup(title: "CONVERT TO") {
                    HStack(spacing: 10) {
                        ForEach(OutputFormat.allCases) { format in
                            PixelChoiceButton(
                                title: format.displayName.uppercased(),
                                isSelected: appState.selectedFormat == format,
                                isEnabled: format != .webP || appState.webPAvailable
                            ) {
                                appState.selectedFormat = format
                            }
                        }
                    }
                }

                PixelChoiceGroup(title: "SAVE TO") {
                    HStack(spacing: 10) {
                        PixelChoiceButton(title: "SAME FOLDER", isSelected: true) {
                            appState.destination = .sameFolder
                        }
                        PixelChoiceButton(title: "CHOOSE FOLDER", isSelected: false, isEnabled: false) {}
                    }
                }

                PixelChoiceGroup(title: "KEEP ORIGINAL") {
                    HStack(spacing: 10) {
                        PixelChoiceButton(title: "KEEP", isSelected: appState.originalPolicy == .keep) {
                            appState.originalPolicy = .keep
                        }
                        PixelChoiceButton(title: "MOVE ASIDE", isSelected: false, isEnabled: false) {}
                        PixelChoiceButton(title: "TRASH", isSelected: false, isEnabled: false) {}
                    }
                }

                PixelChoiceGroup(title: "QUALITY") {
                    HStack(spacing: 10) {
                        ForEach(QualityPreset.allCases) { preset in
                            PixelChoiceButton(
                                title: preset.displayName.uppercased(),
                                isSelected: appState.qualityPreset == preset,
                                isEnabled: appState.selectedFormat.supportsLossyQuality
                            ) {
                                appState.qualityPreset = preset
                            }
                        }
                    }
                }

                Spacer(minLength: 6)

                PixelPrimaryButton(title: "CHOOSE FILES") {
                    appState.chooseFilesForConversion()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .environment(\.pixelButtonFlickerEnabled, true)
    }
}

struct ConversionStatusPageView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completedIntroSessionID: UUID?

    var body: some View {
        let phase = ConversionPresentation.phase(for: appState.conversionPhase,
            sessionID: appState.conversionSessionID, completedIntroSessionID: completedIntroSessionID)
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 26) {
                AnimatedMorphyMascot(phase: phase, reduceMotion: reduceMotion)
                    .id(appState.conversionSessionID)
                    .frame(width: 220, height: 220)

                switch phase {
                case .idle:
                    PixelDarkTitle("READY")
                        .frame(height: 36)
                    Color.clear.frame(height: 54)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    Color.clear.frame(height: 44)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                case .running(let filename):
                    PixelDarkTitle("CONVERTING")
                        .frame(height: 36)
                    PixelDarkSubtitle(filename)
                        .frame(height: 54, alignment: .top)
                    Color.clear.frame(height: 44)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                case .succeeded(let record):
                    PixelDarkTitle("CONVERSION COMPLETED")
                        .frame(height: 36)
                    PixelDarkSubtitle(record.outputFilename ?? "Done")
                        .frame(height: 54, alignment: .top)
                    HStack(spacing: 12) {
                        PixelDarkButton(title: "SHOW") {
                            appState.revealLatestOutputInFinder()
                        }
                        PixelDarkButton(title: "HOME") {
                            appState.navigate(.home)
                        }
                    }
                    .frame(height: 44)
                case .failed(let message):
                    PixelDarkTitle("NEEDS ATTENTION")
                        .frame(height: 36)
                    PixelDarkSubtitle(message)
                        .frame(height: 54, alignment: .top)
                    HStack(spacing: 12) {
                        PixelDarkButton(title: "TRY AGAIN") {
                            appState.navigate(.export)
                        }
                        PixelDarkButton(title: "HOME") {
                            appState.navigate(.home)
                        }
                    }
                    .frame(height: 44)
                }
            }

            BackButton {
                appState.navigate(.export)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(24)
        }
        .task(id: appState.conversionSessionID) {
            let sessionID = appState.conversionSessionID
            completedIntroSessionID = nil
            do {
                try await Task.sleep(for: ConversionPresentation.minimumAnimationDuration)
            } catch {
                return
            }
            guard !Task.isCancelled, sessionID == appState.conversionSessionID else { return }
            completedIntroSessionID = sessionID
        }
    }
}

struct HistoryPageView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PixelFeatureShell {
            VStack(alignment: .leading, spacing: 18) {
                PixelTitle("HISTORY")
                if appState.recentConversions.isEmpty {
                    VStack(spacing: 12) {
                        Image(nsImage: AppImages.colorLogo)
                            .renderingMode(.original)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 96, height: 96)
                        Text("NO CONVERSIONS YET")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(PixelPalette.panelInk)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(appState.recentConversions) { record in
                                HistoryPixelRow(record: record)
                            }
                        }
                    }
                    HStack {
                        PixelPrimaryButton(title: "SHOW LATEST") {
                            appState.revealLatestOutputInFinder()
                        }
                        PixelPrimaryButton(title: "CLEAR") {
                            appState.clearHistory()
                        }
                    }
                }
            }
        }
    }
}

struct SettingsPageView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PixelFeatureShell {
            VStack(alignment: .leading, spacing: 16) {
                PixelTitle("SETTINGS")

                PixelToggleRow(title: "WATCH FOR NEW PHOTOS", isOn: $appState.monitoringEnabled)
                HStack(spacing: 12) {
                    Text("WATCHED FOLDER")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(PixelPalette.panelInk)
                    Spacer(minLength: 0)
                    PixelFolderButton(title: appState.watchedFolder.lastPathComponent,
                        action: appState.chooseWatchedFolder)
                        .frame(maxWidth: 200)
                    .help(appState.watchedFolder.path)
                }
                if appState.monitoringNeedsAccess {
                    Text("Choose the folder to allow access.")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PixelPalette.panelInk)
                }
                PixelToggleRow(title: "SHOW NOTIFICATIONS", isOn: $appState.notificationsEnabled)
                PixelToggleRow(title: "ANIMATE THE LEAVES", isOn: $appState.animateLeaves)
                PixelToggleRow(title: "REMOVE LOCATION INFORMATION", isOn: $appState.removeLocationInformation)

                PixelChoiceGroup(title: "DEFAULT FORMAT") {
                    HStack(spacing: 10) {
                        ForEach(appState.availableFormats) { format in
                            PixelChoiceButton(
                                title: format.displayName.uppercased(),
                                isSelected: appState.selectedFormat == format
                            ) {
                                appState.selectedFormat = format
                            }
                        }
                    }
                }

                PixelChoiceGroup(title: "WHEN morphy FINISHES") {
                    HStack(spacing: 10) {
                        PixelChoiceButton(title: "KEEP ORIGINAL", isSelected: true) {
                            appState.originalPolicy = .keep
                        }
                        PixelChoiceButton(title: "MOVE ASIDE", isSelected: false, isEnabled: false) {}
                        PixelChoiceButton(title: "TRASH", isSelected: false, isEnabled: false) {}
                    }
                }

                Spacer()
            }
        }
        .environment(\.pixelButtonFlickerEnabled, true)
    }
}

struct PixelFeatureShell<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = min(geometry.size.width * 0.90, 820)
            let panelHeight = min(geometry.size.height - 104, 820)
            ZStack {
                PixelPalette.sky.ignoresSafeArea()
                PixelBlobPanel()
                    .frame(width: panelWidth, height: panelHeight)
                content
                    .frame(width: panelWidth * 0.82 - 56, height: panelHeight * 0.88 - 84)
                    .padding(.top, 28)
                    .padding(.bottom, 56)
                    .padding(.horizontal, 28)

                BackButton {
                    appState.navigate(.home)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(24)
            }
        }
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                PixelIcon(kind: .back)
                    .frame(width: 26, height: 26)
                Text("BACK")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .modifier(PixelButtonHoverModifier(restingBackground: PixelPalette.panelInk,
                restingForeground: .white, borderColor: .white, borderWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct HoverAnimatedPixelIcon: View {
    let kind: PixelIcon.Kind
    let isActive: Bool
    let reduceMotion: Bool

    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18, paused: !isActive || reduceMotion)) { context in
            PixelIcon(kind: kind, animationElapsed: isActive && !reduceMotion
                ? max(0, context.date.timeIntervalSince(startedAt)) : 0)
        }
        .onChange(of: isActive) { _, active in
            if active { startedAt = Date() }
        }
    }
}

struct PixelTreeTrunk: View {
    private let barkRows = [
        (0.26, 0.04, 0.13, 0.13),
        (0.75, 0.10, 0.13, 0.04),
        (0.13, 0.16, 0.13, 0.04),
        (0.52, 0.21, 0.13, 0.18),
        (0.26, 0.36, 0.13, 0.10),
        (0.52, 0.53, 0.13, 0.08),
        (0.13, 0.63, 0.13, 0.12),
        (0.39, 0.76, 0.13, 0.12),
        (0.75, 0.84, 0.13, 0.08)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                PixelPalette.trunk
                ForEach(Array(barkRows.enumerated()), id: \.offset) { _, item in
                    Rectangle()
                        .fill(PixelPalette.bark)
                        .frame(width: geometry.size.width * item.2, height: geometry.size.height * item.3)
                        .position(
                            x: geometry.size.width * item.0,
                            y: geometry.size.height * item.1 + geometry.size.height * item.3 / 2
                        )
                }
            }
        }
    }
}

struct PixelLeafSprite: View {
    let isHighlighted: Bool
    var windElapsed: TimeInterval = 0
    var windRate: Double = 1.875
    var windPhase: Double = 0

    var body: some View {
        PixelSprite(
            rows: PixelLeafWind.rows(elapsed: windElapsed, rate: windRate, phase: windPhase),
            palette: [
                "G": isHighlighted ? PixelPalette.leafHighlight : PixelPalette.leaf,
                "B": PixelPalette.trunk
            ]
        )
    }
}

enum PixelLeafWind {
    static let baseRows = [
        "....GGGGGG....", "..GGGGGGGGGG..", ".GGGGGGGGGGGG.",
        ".GGGGGGGGBGGG.", ".GGGGGGBBGGGG.", ".GGGGBBGGGGGG.",
        ".GGBBGGGGGGG..", ".BBGGGGGGG....", "BB............"
    ]

    static func rows(elapsed: TimeInterval, rate: Double, phase: Double) -> [String] {
        guard elapsed != 0 else { return baseRows }
        let wind = sin(elapsed * rate + phase)
        guard abs(wind) > 0.2 else { return baseRows }

        // Four outline cells flex at the tip; a stronger gust changes just one more.
        var edits: [(x: Int, y: Int, pixel: Character)] = wind > 0
            ? [(4, 0, "."), (10, 0, "G"), (2, 1, "."), (12, 1, "G")]
            : [(3, 0, "G"), (9, 0, "."), (1, 1, "G"), (11, 1, ".")]
        if abs(wind) > 0.75 { edits.append((wind > 0 ? 1 : 12, 2, ".")) }
        var grid = baseRows.map { Array($0) }
        for edit in edits { grid[edit.y][edit.x] = edit.pixel }
        return grid.map { String($0) }
    }
}

struct PixelIcon: View {
    enum Kind: Equatable {
        case export
        case history
        case settings
        case back
    }

    let kind: Kind
    var animationElapsed: TimeInterval = 0

    var body: some View {
        Group {
            if kind == .back {
                Rectangle().fill(.foreground)
                    .mask(PixelSprite(rows: rows, palette: palette))
            } else {
                PixelSprite(rows: rows, palette: palette)
            }
        }
        .accessibilityHidden(true)
    }

    private var palette: [Character: Color] {
        ["W": .white]
    }

    var rows: [String] {
        switch kind {
        case .export:
            exportRows
        case .history:
            historyRows
        case .settings:
            settingsRows
        case .back:
            [
                "....W...",
                "...WW...",
                "..WWW...",
                ".WWWWWWW",
                ".WWWWWWW",
                "..WWW...",
                "...WW...",
                "....W..."
            ]
        }
    }

    private var exportRows: [String] {
        var grid = Array(repeating: Array(repeating: Character("."), count: 12), count: 10)
        for y in 5...8 {
            grid[y][1] = "W"
            grid[y][10] = "W"
        }
        for x in 1...10 { grid[8][x] = "W" }
        let arrow = ["....WWWW....", "...WWWWWW...", "..WW.WW.WW..",
                     ".....WW.....", ".....WW.....", ".....WW.....", ".....WW....."]
        let rise = Int(animationElapsed * 1.5 / 0.18) % 10
        for (y, row) in arrow.enumerated() where y >= rise {
            for (x, pixel) in row.enumerated() where pixel == "W" {
                grid[y - rise][x] = "W"
            }
        }
        return grid.map { String($0) }
    }

    private var historyRows: [String] {
        var grid = ["...WWWWWW...", "..WW....WW..", ".WW......WW.", ".W........W.",
                    "WW........WW", "WW........WW", ".W........W.", ".WW......WW.",
                    "..WW....WW..", "...WWWWWW..."].map { Array($0) }
        let minuteAngle = animationElapsed * .pi
        let hourAngle = .pi / 2 + animationElapsed * .pi / 12
        for (angle, length) in [(minuteAngle, 3), (hourAngle, 2)] {
            for distance in 0...length {
                let x = 5 + Int((sin(angle) * Double(distance)).rounded())
                let y = 4 - Int((cos(angle) * Double(distance)).rounded())
                paintBlock(x: x, y: y, in: &grid)
            }
        }
        return grid.map { String($0) }
    }

    private var settingsRows: [String] {
        var grid = Array(repeating: Array(repeating: Character("."), count: 12), count: 10)
        let phases = [Double.pi - asin(2.0 / 3), -asin(2.0 / 3), Double.pi]
        for (index, row) in [1, 4, 7].enumerated() {
            for x in 1...10 { grid[row][x] = "W" }
            let x = Int((5 + 3 * sin(animationElapsed * .pi / 2 + phases[index])).rounded())
            for y in (row - 1)...(row + 1) {
                grid[y][x] = "W"
                grid[y][x + 1] = "W"
            }
        }
        return grid.map { String($0) }
    }

    private func paintBlock(x: Int, y: Int, in grid: inout [[Character]]) {
        for row in y..<(y + 2) where grid.indices.contains(row) {
            for column in x..<(x + 2) where grid[row].indices.contains(column) {
                grid[row][column] = "W"
            }
        }
    }
}

struct PixelSprite: View {
    let rows: [String]
    let palette: [Character: Color]

    var body: some View {
        Canvas { context, size in
            let rowCount = rows.count
            let columnCount = rows.map(\.count).max() ?? 1
            let cell = floor(min(
                size.width / CGFloat(columnCount),
                size.height / CGFloat(max(1, rowCount))
            ))
            let xOffset = (size.width - cell * CGFloat(columnCount)) / 2
            let yOffset = (size.height - cell * CGFloat(rowCount)) / 2

            for (y, row) in rows.enumerated() {
                let characters = Array(row)
                var x = 0
                while x < characters.count {
                    let character = characters[x]
                    let start = x
                    while x < characters.count && characters[x] == character { x += 1 }
                    if let color = palette[character] {
                        let rect = CGRect(x: xOffset + CGFloat(start) * cell, y: yOffset + CGFloat(y) * cell,
                            width: CGFloat(x - start) * cell, height: cell)
                        context.fill(Path(rect), with: .color(color), style: FillStyle(antialiased: false))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct PixelBlobPanel: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Rectangle()
                    .fill(PixelPalette.panel)
                    .frame(width: w * 0.82, height: h * 0.88)
                Rectangle()
                    .fill(PixelPalette.panel)
                    .frame(width: w * 0.70, height: h)
                Rectangle()
                    .fill(PixelPalette.panel)
                    .frame(width: w, height: h * 0.66)
                Rectangle()
                    .fill(PixelPalette.panel)
                    .frame(width: w * 0.90, height: h * 0.76)
            }
        }
    }
}

struct PixelChoiceGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(PixelPalette.panelInk)
            content
        }
    }
}

struct PixelChoiceButton: View {
    let title: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 40)
                .modifier(PixelButtonHoverModifier(
                    restingBackground: isSelected ? PixelPalette.leafHighlight : Color.white.opacity(0.88),
                    restingForeground: PixelPalette.panelInk, borderColor: PixelPalette.panelInk,
                    borderWidth: isSelected ? 4 : 2))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct PixelPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .modifier(PixelButtonHoverModifier(restingBackground: PixelPalette.panelInk,
                    restingForeground: .white, borderColor: .white, borderWidth: 3))
        }
        .buttonStyle(.plain)
    }
}

private struct PixelButtonFlickerKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var pixelButtonFlickerEnabled: Bool {
        get { self[PixelButtonFlickerKey.self] }
        set { self[PixelButtonFlickerKey.self] = newValue }
    }
}

private struct PixelButtonHoverModifier: ViewModifier {
    let restingBackground: Color
    let restingForeground: Color
    let borderColor: Color
    let borderWidth: CGFloat

    @Environment(\.pixelButtonFlickerEnabled) private var flickerEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        PixelButtonHoverSurface(isHovered: flickerEnabled && isEnabled && isHovering,
            reduceMotion: reduceMotion, restingBackground: restingBackground,
            restingForeground: isEnabled ? restingForeground : restingForeground.opacity(0.35),
            borderColor: borderColor, borderWidth: borderWidth, label: content)
            .onHover { isHovering = $0 }
    }
}

struct PixelButtonHoverSurface<Label: View>: View {
    let isHovered: Bool
    let reduceMotion: Bool
    let restingBackground: Color
    let restingForeground: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let label: Label

    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !isHovered || reduceMotion)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let greenPhase = reduceMotion || Int(elapsed / 0.4) % 2 == 0
            label
                .foregroundStyle(isHovered ? PixelPalette.panelInk : restingForeground)
                .background(isHovered ? (greenPhase ? PixelPalette.leafHighlight : .white) : restingBackground)
                .overlay(Rectangle().stroke(isHovered ? PixelPalette.panelInk : borderColor, lineWidth: borderWidth))
        }
        .onChange(of: isHovered) { _, hovered in
            if hovered { startedAt = Date() }
        }
    }
}

struct PixelDarkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white)
        }
        .buttonStyle(.plain)
    }
}

struct PixelTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .black, design: .monospaced))
            .foregroundStyle(PixelPalette.panelInk)
            .minimumScaleFactor(0.8)
    }
}

struct PixelDarkTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
    }
}

struct PixelDarkSubtitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.84))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 40)
    }
}

struct PixelToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(PixelPalette.panelInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(PixelToggleStyle())
    }
}

struct PixelToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 16) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                PixelSwitchGlyph(isOn: configuration.isOn, isHighlighted: isHovered && isEnabled)
                    .frame(width: 64, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovered = $0 }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }
}

struct PixelSwitchGlyph: View {
    let isOn: Bool
    var isHighlighted = false

    var rows: [String] {
        var grid = ["..EEEEEEEEEEEE..", ".ETTTTTTTTTTTTE.", "ETTTTTTTTTTTTTTE",
                    "ETTTTTTTTTTTTTTE", "ETTTTTTTTTTTTTTE", "ETTTTTTTTTTTTTTE",
                    ".ETTTTTTTTTTTTE.", "..EEEEEEEEEEEE.."].map { Array($0) }
        let thumb = [".EEEE.", "EWWWWE", "EWWWWE", "EWWWWE", "EWWWWE", ".EEEE."]
        let origin = isOn ? 9 : 1
        for (y, row) in thumb.enumerated() {
            for (x, pixel) in row.enumerated() where pixel != "." {
                grid[y + 1][x + origin] = pixel
            }
        }
        return grid.map { String($0) }
    }

    var body: some View {
        PixelSprite(rows: rows, palette: ["E": PixelPalette.panelInk,
            "T": isOn || isHighlighted ? PixelPalette.leafHighlight : .white.opacity(0.88), "W": .white])
    }
}

struct PixelFolderButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                PixelSprite(rows: [".WWWW.......", "W....WWWWWW.", "W.........W.",
                    "WWWWWWWWWWW.", "W.........W.", "W.........W.", "W.........W.", "WWWWWWWWWWW."],
                    palette: ["W": PixelPalette.panelInk])
                    .frame(width: 24, height: 20)
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .modifier(PixelButtonHoverModifier(restingBackground: .white.opacity(0.88),
                restingForeground: PixelPalette.panelInk, borderColor: PixelPalette.panelInk, borderWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Watched folder: \(title)")
        .accessibilityHint("Choose a folder to watch for new photos")
    }
}

struct HistoryPixelRow: View {
    let record: ConversionRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.status == .completed ? "OK" : "!")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(record.status == .completed ? PixelPalette.leaf : Color.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.sourceFilename)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelPalette.panelInk)
                    .lineLimit(1)
                Text("\(record.sourceFormat.uppercased()) -> \(record.outputFormat.displayName.uppercased())")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(PixelPalette.panelInk.opacity(0.7))
            }
            Spacer()
            if let outputFileSize = record.outputFileSize {
                Text(ByteCountFormatter.string(fromByteCount: outputFileSize, countStyle: .file))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(PixelPalette.panelInk.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.78))
        .overlay(Rectangle().stroke(PixelPalette.panelInk, lineWidth: 2))
    }
}

struct AnimatedMorphyMascot: View {
    let phase: ConversionPhase
    let reduceMotion: Bool
    @State private var startedAt = Date()

    private let colors: [Color] = [
        .green,
        .cyan,
        .yellow,
        .orange,
        .red,
        .purple
    ]

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: reduceMotion ? 2.0 : 0.45)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let colorIndex = Int(elapsed / (reduceMotion ? 2.0 : 0.45)) % colors.count
            mascot(color: color(for: colorIndex))
        }
    }

    @ViewBuilder
    private func mascot(color: Color) -> some View {
        switch phase {
        case .running:
            Image(nsImage: AppImages.monochromeLogo)
                .resizable()
                .renderingMode(.template)
                .interpolation(.none)
                .foregroundStyle(color)
        case .failed:
            Image(nsImage: AppImages.monochromeLogo)
                .resizable()
                .renderingMode(.template)
                .interpolation(.none)
                .foregroundStyle(.red)
        default:
            Image(nsImage: AppImages.colorLogo)
                .renderingMode(.original)
                .resizable()
                .interpolation(.none)
        }
    }

    private func color(for index: Int) -> Color {
        colors[index]
    }
}

enum PixelPalette {
    static let forest = Color(red: 0.18, green: 0.34, blue: 0.19)
    static let trunk = Color(red: 0.58, green: 0.31, blue: 0.08)
    static let bark = Color(red: 0.43, green: 0.23, blue: 0.05)
    static let leaf = Color(red: 0.03, green: 0.62, blue: 0.03)
    static let leafHighlight = Color(red: 0.18, green: 0.83, blue: 0.14)
    static let leafInk = Color(red: 0.02, green: 0.22, blue: 0.05)
    static let sky = Color(red: 0.07, green: 0.76, blue: 0.86)
    static let panel = Color(red: 0.74, green: 0.61, blue: 0.14)
    static let panelInk = Color(red: 0.14, green: 0.10, blue: 0.04)
}
