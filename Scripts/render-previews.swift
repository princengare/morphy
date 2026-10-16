import AppKit
import ImageIO
import MorphyCore
import SwiftUI

@main
struct PreviewExporter {
    @MainActor
    static func main() async throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if CommandLine.arguments.contains("--icons-only") {
            try renderIconAnimations(in: directory)
            return
        }
        if CommandLine.arguments.contains("--buttons-only") {
            try renderButtonAnimations(in: directory)
            return
        }
        if CommandLine.arguments.contains("--home-motion-only") {
            try renderHomeAnimation(in: directory)
            return
        }
        if CommandLine.arguments.contains("--conversion-motion-only") {
            try await renderConversionAnimations(in: directory)
            return
        }
        let inspector = WebPCapabilityInspector()
        let environment = AppEnvironment(
            converter: ImageConversionService(webPInspector: inspector),
            historyStore: InMemoryHistoryStore(),
            webPInspector: inspector
        )
        let state = AppState(environment: environment)
        state.animateLeaves = false
        for (name, route) in [("home", AppRoute.home), ("export", .export), ("settings", .settings)] {
            state.navigate(route)
            try await render(RootPixelAppView().environmentObject(state), name: name, in: directory)
        }
        state.navigate(.home)
        try await render(RootPixelAppView().environmentObject(state), name: "home-wide", in: directory, size: CGSize(width: 1000, height: 720))
        state.navigate(.export)
        state.selectedFormat = .png
        try await render(RootPixelAppView().environmentObject(state), name: "export-minimum", in: directory, size: CGSize(width: 720, height: 720))
        state.navigate(.settings)
        try await render(RootPixelAppView().environmentObject(state), name: "settings-minimum", in: directory, size: CGSize(width: 720, height: 720))
        state.selectedFormat = .jpeg
        try await render(MenuBarRootView().environmentObject(state), name: "menu-bar", in: directory, size: CGSize(width: 232, height: 128))
        try await render(MenuBarRootView(morphingInitiallyExpanded: true).environmentObject(state),
            name: "menu-bar-expanded", in: directory, size: CGSize(width: 232, height: 244))
        try await render(MenuBarRootView(morphingInitiallyExpanded: true).environmentObject(state),
            name: "menu-bar-dark", in: directory, size: CGSize(width: 232, height: 244), colorScheme: .dark)
        let collapsedMenu = try Data(contentsOf: directory.appendingPathComponent("menu-bar.png"))
        let expandedMenu = try Data(contentsOf: directory.appendingPathComponent("menu-bar-expanded.png"))
        let openRow = CGRect(x: 0, y: 0, width: 232, height: 40)
        guard try croppedPixels(in: collapsedMenu, rect: openRow, canvasWidth: 232)
            == croppedPixels(in: expandedMenu, rect: openRow, canvasWidth: 232) else {
            throw NSError(domain: "MorphyPreview", code: 13,
                userInfo: [NSLocalizedDescriptionKey: "Open morphy moved when the disclosure expanded."])
        }
        print("Verified the menu's open morphy row stays fixed when morphing expands.")
        try await render(PixelFolderButton(title: "A very long incoming photographs folder name") {},
            name: "folder-button-long-name", in: directory, size: CGSize(width: 200, height: 40))

        let sourceURL = directory.appendingPathComponent("morphy-sample.heic")
        try makeSampleHEIC(at: sourceURL)
        let record = try await environment.converter.convert(ImageConversionRequest(
            sourceURL: sourceURL, targetFormat: .jpeg, duplicatePolicy: .replaceExisting
        ))
        try await environment.historyStore.add(record)
        await state.refreshHistory()
        state.conversionPhase = .succeeded(record: record)
        state.navigate(.conversion)
        try await render(RootPixelAppView().environmentObject(state), name: "complete", in: directory, settlingTime: 3.2)
        state.navigate(.history)
        try await render(RootPixelAppView().environmentObject(state), name: "history", in: directory)
        print("Converted \(record.sourceFilename) to \(record.outputFilename ?? "JPEG"); original retained.")
        print("Rendered previews in \(directory.path)")
    }

    @MainActor
    static func render<V: View>(_ view: V, name: String, in directory: URL, size: CGSize = CGSize(width: 760, height: 760),
        colorScheme: ColorScheme = .light, settlingTime: TimeInterval = 0.2) async throws {
        let hostingView = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .environment(\.colorScheme, colorScheme)
            .background(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = hostingView
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.setFrameOrigin(CGPoint(x: -10000, y: -10000))
        window.orderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .seconds(settlingTime))
        pumpRunLoop(0.02)
        hostingView.displayIfNeeded()
        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "MorphyPreview", code: 1)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MorphyPreview", code: 1)
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }

    @MainActor
    static func makeSampleHEIC(at url: URL) throws {
        let logoURL = Bundle.morphyResources.url(forResource: "logo-color", withExtension: "png")!
        let logoSource = CGImageSourceCreateWithURL(logoURL as CFURL, nil)!
        let logo = CGImageSourceCreateImageAtIndex(logoSource, 0, nil)!
        let context = CGContext(data: nil, width: 1024, height: 1024,
            bitsPerComponent: 8, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        context.interpolationQuality = .none
        context.draw(logo, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.heic" as CFString, 1, nil) else {
            throw NSError(domain: "MorphyPreview", code: 2)
        }
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MorphyPreview", code: 3)
        }
    }

    @MainActor
    static func renderIconAnimations(in directory: URL) throws {
        let size = CGSize(width: 760, height: 300)
        let state = IconPreviewState()
        let hosting = NSHostingView(rootView: IconAnimationPreview(state: state)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        window.setFrameOrigin(CGPoint(x: -10000, y: -10000))
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let frames = directory.appendingPathComponent("icon-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        let clock = ContinuousClock()
        let started = clock.now
        var sceneSnapshots: [[Data]] = Array(repeating: [], count: 3)
        for frame in 0..<192 {
            let scene = min(2, frame / 60)
            state.active = [PixelIcon.Kind.export, .history, .settings][scene]
            let deadline = started.advanced(by: .milliseconds(Int64((frame + 1) * 1000 / 12)))
            let remaining = clock.now.duration(to: deadline)
            let seconds = Double(remaining.components.seconds) + Double(remaining.components.attoseconds) / 1e18
            if seconds > 0 { RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds)) }
            hosting.layoutSubtreeIfNeeded()
            let data = try capture(hosting)
            if frame % 12 == 0 { sceneSnapshots[scene].append(data) }
            try data.write(to: frames.appendingPathComponent(String(format: "frame-%03d.png", frame)))
        }
        for snapshots in sceneSnapshots {
            guard Set(snapshots).count > 1 else {
                throw NSError(domain: "MorphyPreview", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "An active icon did not animate."])
            }
        }
        state.active = nil
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let idle = try capture(hosting)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        guard try capture(hosting) == idle else {
            throw NSError(domain: "MorphyPreview", code: 5,
                userInfo: [NSLocalizedDescriptionKey: "An idle icon continued animating."])
        }
        state.reduceMotion = true
        state.active = .export
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let reduced = try capture(hosting)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        guard try capture(hosting) == reduced else {
            throw NSError(domain: "MorphyPreview", code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Reduce Motion did not stop icon animation."])
        }
        print("Verified moving icons, idle reset, and Reduce Motion. Captured 192 live-rendered frames.")
    }

    @MainActor
    static func capture(_ view: NSView) throws -> Data {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "MorphyPreview", code: 1)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "MorphyPreview", code: 1)
        }
        return data
    }

    static func croppedPixels(in data: Data, rect: CGRect, canvasWidth: CGFloat) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "MorphyPreview", code: 14)
        }
        let scale = CGFloat(image.width) / canvasWidth
        let region = CGRect(x: rect.minX * scale, y: rect.minY * scale,
            width: rect.width * scale, height: rect.height * scale).integral
        guard let crop = image.cropping(to: region) else { throw NSError(domain: "MorphyPreview", code: 14) }
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height,
                bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw NSError(domain: "MorphyPreview", code: 14)
            }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        }
        return Data(pixels)
    }

    @MainActor
    static func pumpRunLoop(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }

    static func conversionPositions(in data: Data) throws -> (mascot: CGRect, title: Int, subtitle: Int) {
        guard let image = NSBitmapImageRep(data: data)?.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "MorphyPreview", code: 16)
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                throw NSError(domain: "MorphyPreview", code: 16)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var minX = width, minY = height, maxX = -1, maxY = -1
        var whiteRows = [Bool](repeating: false, count: height)
        var grayRows = [Bool](repeating: false, count: height)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
                let light = max(r, max(g, b)), dark = min(r, min(g, b))
                if light > 128 && light - dark > 60 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
                if x >= width / 5 && x < width * 4 / 5 {
                    if dark > 245 { whiteRows[y] = true }
                    if dark > 150 && light < 240 && light - dark < 5 { grayRows[y] = true }
                }
            }
        }
        guard maxX >= minX else { throw NSError(domain: "MorphyPreview", code: 16) }
        let mascotCenter = (minY + maxY) / 2
        guard let title = whiteRows.indices.filter({ whiteRows[$0] })
            .min(by: { abs($0 - mascotCenter) < abs($1 - mascotCenter) }) else {
            throw NSError(domain: "MorphyPreview", code: 16)
        }
        let direction = title > mascotCenter ? 1 : -1
        var titleEnd = title
        while whiteRows.indices.contains(titleEnd + direction) && whiteRows[titleEnd + direction] {
            titleEnd += direction
        }
        guard let subtitle = grayRows.indices.filter({ grayRows[$0] && ($0 - titleEnd) * direction > 10 })
            .min(by: { abs($0 - titleEnd) < abs($1 - titleEnd) }) else {
            throw NSError(domain: "MorphyPreview", code: 16)
        }
        return (CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1), title, subtitle)
    }

    @MainActor
    static func renderConversionAnimations(in directory: URL) async throws {
        let frames = directory.appendingPathComponent("conversion-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        var outputFrame = 0
        for (name, delay, frameCount) in [("fast", Duration.zero, 54), ("slow", .seconds(4.2), 72)] {
            let filename = name == "slow"
                ? String(repeating: "incoming-photo-", count: 14) + "slow.heic" : "conversion-fast.heic"
            let source = directory.appendingPathComponent(filename)
            try makeSampleHEIC(at: source)
            let state = AppState(environment: AppEnvironment(converter: PreviewDelayedConverter(delay: delay),
                historyStore: InMemoryHistoryStore(), webPInspector: WebPCapabilityInspector()))
            state.startManualConversion(urls: [source])
            let size = CGSize(width: 760, height: 760)
            let hosting = NSHostingView(rootView: RootPixelAppView().environmentObject(state)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .light))
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = hosting
            window.setFrameOrigin(CGPoint(x: -10000, y: -10000))
            window.orderFront(nil)
            defer {
                window.orderOut(nil)
                window.contentView = nil
            }
            let clock = ContinuousClock()
            let started = clock.now
            var beforeMinimum: Data?
            var afterMinimum: Data?
            var completed: Data?
            var finalFrames: Set<Data> = []
            var introFrames: Set<Data> = []
            for frame in 0..<frameCount {
                try await clock.sleep(until: started.advanced(by: .milliseconds(Int64((frame + 1) * 1000 / 12))))
                pumpRunLoop(0.005)
                hosting.layoutSubtreeIfNeeded()
                hosting.displayIfNeeded()
                let data = try capture(hosting)
                try data.write(to: frames.appendingPathComponent(String(format: "frame-%03d.png", outputFrame)))
                outputFrame += 1
                if frame < 32 { introFrames.insert(data) }
                if frame == 33 {
                    beforeMinimum = data
                    if name == "fast" {
                        guard case .succeeded = state.conversionPhase else {
                            throw NSError(domain: "MorphyPreview", code: 13,
                                userInfo: [NSLocalizedDescriptionKey: "The fast conversion did not finish before three seconds."])
                        }
                    }
                    try data.write(to: directory.appendingPathComponent("conversion-\(name)-before-minimum.png"))
                }
                if frame == 41 {
                    afterMinimum = data
                    if name == "slow" {
                        guard case .running = state.conversionPhase else {
                            throw NSError(domain: "MorphyPreview", code: 14,
                                userInfo: [NSLocalizedDescriptionKey: "The slow conversion was not still running after three seconds."])
                        }
                    }
                    try data.write(to: directory.appendingPathComponent("conversion-\(name)-after-minimum.png"))
                }
                if frame >= frameCount - 5 { finalFrames.insert(data); completed = data }
            }
            guard case .succeeded = state.conversionPhase, let completed, let beforeMinimum,
                  finalFrames.count == 1, introFrames.count > 1, beforeMinimum != completed,
                  name != "slow" || afterMinimum != completed else {
                throw NSError(domain: "MorphyPreview", code: 15,
                    userInfo: [NSLocalizedDescriptionKey: "Conversion timing or color animation did not match the requested behavior."])
            }
            try completed.write(to: directory.appendingPathComponent("conversion-\(name)-completed.png"))
            let before = try conversionPositions(in: beforeMinimum)
            let after = try conversionPositions(in: completed)
            guard abs(before.mascot.minY - after.mascot.minY) <= 2,
                  abs(before.mascot.midX - after.mascot.midX) <= 2,
                  abs(before.title - after.title) <= 2, abs(before.subtitle - after.subtitle) <= 2 else {
                throw NSError(domain: "MorphyPreview", code: 17,
                    userInfo: [NSLocalizedDescriptionKey: "Completion buttons moved the mascot or text: \(before) -> \(after)"])
            }
        }
        print("Verified conversion timing and fixed mascot/title/filename positions when buttons appear, including a wrapped filename. Captured \(outputFrame) frames.")
    }

    @MainActor
    static func renderButtonAnimations(in directory: URL) throws {
        let state = ButtonPreviewState()
        let size = CGSize(width: 760, height: 380)
        let hosting = NSHostingView(rootView: ButtonAnimationPreview(state: state)
            .frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        window.setFrameOrigin(CGPoint(x: -10000, y: -10000))
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let frames = directory.appendingPathComponent("button-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        var snapshots: Set<Data> = []
        for frame in 0..<36 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0 / 12))
            hosting.layoutSubtreeIfNeeded()
            let data = try capture(hosting)
            snapshots.insert(data)
            try data.write(to: frames.appendingPathComponent(String(format: "frame-%03d.png", frame)))
        }
        guard snapshots.count > 1 else {
            throw NSError(domain: "MorphyPreview", code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Hovered buttons did not flicker."])
        }
        state.hovered = false
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let idle = try capture(hosting)
        try idle.write(to: directory.appendingPathComponent("buttons-idle.png"))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
        guard try capture(hosting) == idle else {
            throw NSError(domain: "MorphyPreview", code: 8,
                userInfo: [NSLocalizedDescriptionKey: "Buttons kept flickering after hover exit."])
        }
        state.reduceMotion = true
        state.hovered = true
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let reduced = try capture(hosting)
        try reduced.write(to: directory.appendingPathComponent("buttons-reduced-motion.png"))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
        guard try capture(hosting) == reduced else {
            throw NSError(domain: "MorphyPreview", code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Reduce Motion did not stop button flicker."])
        }
        print("Verified button flicker, idle reset, and steady Reduce Motion highlight. Captured 36 frames.")
    }

    @MainActor
    static func renderHomeAnimation(in directory: URL) throws {
        let state = HomePreviewState()
        let size = CGSize(width: 760, height: 760)
        let hosting = NSHostingView(rootView: HomeAnimationPreview(state: state)
            .frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        window.setFrameOrigin(CGPoint(x: -10000, y: -10000))
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let frames = directory.appendingPathComponent("home-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        let clock = ContinuousClock()
        let started = clock.now
        var snapshots: [Set<Data>] = Array(repeating: [], count: 4)
        var sampledFrames: [[Data]] = Array(repeating: [], count: 4)
        var leafSnapshots: [[Set<Data>]] = Array(repeating: Array(repeating: [], count: 3), count: 4)
        for frame in 0..<144 {
            let scene = frame / 36
            state.active = scene == 0 ? nil : HomeNavigationSection.allCases[scene - 1]
            let deadline = started.advanced(by: .milliseconds(Int64((frame + 1) * 1000 / 18)))
            let remaining = clock.now.duration(to: deadline)
            let seconds = Double(remaining.components.seconds) + Double(remaining.components.attoseconds) / 1e18
            if seconds > 0 { RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds)) }
            hosting.layoutSubtreeIfNeeded()
            let data = try capture(hosting)
            snapshots[scene].insert(data)
            if frame % 36 >= 6 && frame % 6 == 0 { sampledFrames[scene].append(data) }
            try data.write(to: frames.appendingPathComponent(String(format: "frame-%03d.png", frame)))
        }
        for scene in 0..<4 {
            guard snapshots[scene].count > 1 else {
                throw NSError(domain: "MorphyPreview", code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "Home animation scene \(scene) did not move."])
            }
            for index in 0..<3 {
                let section = HomeNavigationSection.allCases[index]
                let rect = HomeNavigationLayout(section: section, canvasSize: size).leafFrame
                for data in sampledFrames[scene] {
                    leafSnapshots[scene][index].insert(try croppedPixels(in: data, rect: rect, canvasWidth: size.width))
                }
                let expectedPaused = scene > 0 && index == scene - 1
                guard expectedPaused ? leafSnapshots[scene][index].count == 1 : leafSnapshots[scene][index].count > 1 else {
                    throw NSError(domain: "MorphyPreview", code: 15,
                        userInfo: [NSLocalizedDescriptionKey: "Hover did not pause only its matching leaf, or the leaf did not resume."])
                }
            }
        }
        state.reduceMotion = true
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let reduced = try capture(hosting)
        try reduced.write(to: directory.appendingPathComponent("home-reduced-motion.png"))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        guard try capture(hosting) == reduced else {
            throw NSError(domain: "MorphyPreview", code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Reduce Motion did not stop home animation."])
        }
        state.reduceMotion = false
        state.animateLeaves = false
        state.active = nil
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let idle = try capture(hosting)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        guard try capture(hosting) == idle else {
            throw NSError(domain: "MorphyPreview", code: 12,
                userInfo: [NSLocalizedDescriptionKey: "Disabling leaf animation did not stop idle wind."])
        }
        print("Verified shared wind, per-action leaf pause/resume, Reduce Motion, and disabled wind. Captured 144 frames at 18 fps.")
    }
}

private struct PreviewDelayedConverter: ImageConverting {
    let delay: Duration

    func convert(_ request: ImageConversionRequest) async throws -> ConversionRecord {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try await ImageConversionService().convert(request)
    }
}

@MainActor
private final class HomePreviewState: ObservableObject {
    @Published var active: HomeNavigationSection?
    @Published var reduceMotion = false
    @Published var animateLeaves = true
}

private struct HomeAnimationPreview: View {
    @ObservedObject var state: HomePreviewState

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                PixelPalette.forest
                PixelTreeTrunk().frame(width: geometry.size.width * 0.25, height: geometry.size.height)
                ForEach(HomeNavigationSection.allCases) { section in
                    HomeNavigationBand(section: section, canvasSize: geometry.size,
                        isHovered: state.active == section, animateLeaves: state.animateLeaves,
                        reduceMotion: state.reduceMotion) {}
                        .frame(width: geometry.size.width, height: geometry.size.height * section.bandHeight)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * section.bandCenter)
                }
            }
        }
    }
}

@MainActor
private final class IconPreviewState: ObservableObject {
    @Published var active: PixelIcon.Kind? = .export
    @Published var reduceMotion = false
}

private struct IconAnimationPreview: View {
    @ObservedObject var state: IconPreviewState

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 42) {
                ForEach(Array([PixelIcon.Kind.export, .history, .settings].enumerated()), id: \.offset) { index, kind in
                    VStack(spacing: 12) {
                        Text(["EXPORT", "HISTORY", "SETTINGS"][index])
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                        HoverAnimatedPixelIcon(kind: kind, isActive: state.active == kind, reduceMotion: state.reduceMotion)
                            .frame(width: 152, height: 152)
                    }
                }
            }
            Text(caption)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelPalette.forest)
    }

    private var caption: String {
        switch state.active {
        case .export: "EXPORT LEAF HOVER"
        case .history: "HISTORY LEAF HOVER"
        case .settings: "SETTINGS LEAF HOVER"
        default: "IDLE"
        }
    }
}

@MainActor
private final class ButtonPreviewState: ObservableObject {
    @Published var hovered = true
    @Published var reduceMotion = false
}

private struct ButtonAnimationPreview: View {
    @ObservedObject var state: ButtonPreviewState

    var body: some View {
        VStack(spacing: 24) {
            Text("OPTIONS BUTTON HOVER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(PixelPalette.panelInk)
            HStack(spacing: 24) {
                surface(background: PixelPalette.leafHighlight, foreground: PixelPalette.panelInk,
                    border: PixelPalette.panelInk, width: 4,
                    label: Text("JPEG").font(.system(size: 13, weight: .black, design: .monospaced))
                        .frame(width: 220, height: 40))
                surface(background: .white.opacity(0.88), foreground: PixelPalette.panelInk,
                    border: PixelPalette.panelInk, width: 2,
                    label: Text("PNG").font(.system(size: 13, weight: .black, design: .monospaced))
                        .frame(width: 220, height: 40))
            }
            HStack(spacing: 24) {
                surface(background: PixelPalette.panelInk, foreground: .white, border: .white, width: 3,
                    label: Text("CHOOSE FILES").font(.system(size: 17, weight: .black, design: .monospaced))
                        .padding(.horizontal, 24).padding(.vertical, 14))
                surface(background: PixelPalette.panelInk, foreground: .white, border: .white, width: 2,
                    label: HStack(spacing: 8) {
                        PixelIcon(kind: .back).frame(width: 26, height: 26)
                        Text("BACK").font(.system(size: 15, weight: .black, design: .monospaced))
                    }.padding(.horizontal, 12).padding(.vertical, 9))
            }
            PixelChoiceButton(title: "TRASH", isSelected: false, isEnabled: false) {}
                .frame(width: 160)
                .environment(\.pixelButtonFlickerEnabled, true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelPalette.panel)
    }

    private func surface<V: View>(background: Color, foreground: Color, border: Color, width: CGFloat, label: V) -> some View {
        PixelButtonHoverSurface(isHovered: state.hovered, reduceMotion: state.reduceMotion,
            restingBackground: background, restingForeground: foreground,
            borderColor: border, borderWidth: width, label: label)
    }
}
