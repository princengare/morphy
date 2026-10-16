import Foundation
import SwiftUI
import Testing
@testable import MorphyApp

@Suite("Pixel navigation and animation")
@MainActor
struct PixelPresentationTests {
    @Test("Home actions retain their destinations and share one wind cycle")
    func homeNavigationBands() {
        let sections = HomeNavigationSection.allCases
        #expect(sections.first?.bandTop == 0)
        #expect(sections.last?.bandBottom == 1)
        for (index, section) in sections.enumerated() {
            #expect(section.leafCenter > section.bandTop && section.leafCenter < section.bandBottom)
            #expect(section.iconCenter > section.bandTop && section.iconCenter < section.bandBottom)
            #expect(section.bandHeight > 0)
            if index > 0 { #expect(sections[index - 1].bandBottom == section.bandTop) }
        }
        for sample in 0..<1000 {
            let y = CGFloat(sample) / 1000
            #expect(sections.filter { y >= $0.bandTop && y < $0.bandBottom }.count == 1)
        }
        #expect(sections.map(\.route) == [.export, .history, .settings])
        #expect(Set(sections.map(\.windRate)).count == 1)
        #expect(Set(sections.map(\.windRotation)).count == 3)
        #expect(sections.allSatisfy { $0.windRotation > 0 && $0.windRotation < 1 })
    }

    @Test("Wind changes only four or five outline pixels and keeps the branch fixed")
    func anchoredPixelWind() {
        let idle = PixelLeafWind.rows(elapsed: 0, rate: 1, phase: 0)
        #expect(idle == PixelLeafWind.baseRows)
        let branches = coordinates(of: "B", in: idle)
        var frames: Set<[String]> = []
        for section in HomeNavigationSection.allCases {
            var previous = idle
            for step in 1...360 {
                let rows = PixelLeafWind.rows(elapsed: Double(step) / 18,
                    rate: section.windRate, phase: 0)
                #expect(rows.count == 9)
                #expect(rows.allSatisfy { $0.count == 14 })
                #expect(coordinates(of: "B", in: rows) == branches)
                #expect(rows.suffix(6) == idle.suffix(6))
                let changes = differenceCount(rows, idle)
                #expect(changes == 0 || changes == 4 || changes == 5)
                #expect(differenceCount(rows, previous) <= 5)
                frames.insert(rows)
                previous = rows
            }
        }
        #expect(frames.count == 5)
        #expect(PixelLeafWind.rows(elapsed: 0, rate: 2, phase: 4) == idle)
    }

    @Test("Every horizontal row is interactive right up to, but never inside, the trunk")
    func rowHitAreasExcludeTrunk() {
        for size in [CGSize(width: 720, height: 720), CGSize(width: 760, height: 760), CGSize(width: 1000, height: 720)] {
            let layouts = HomeNavigationSection.allCases.map { HomeNavigationLayout(section: $0, canvasSize: size) }
            let trunkWidth = size.width * 0.25
            for layout in layouts {
                let frame = layout.interactiveFrame
                #expect(frame.minX == trunkWidth)
                #expect(frame.maxX == size.width)
                #expect(frame.minY == layout.bandFrame.minY)
                #expect(frame.maxY == layout.bandFrame.maxY)
                #expect(!frame.contains(CGPoint(x: trunkWidth - 0.01, y: frame.midY)))
                #expect(frame.contains(CGPoint(x: trunkWidth, y: frame.midY)))
                #expect(frame.contains(CGPoint(x: size.width - 0.01, y: frame.midY)))
                #expect(frame.contains(CGPoint(x: layout.leafFrame.midX, y: layout.leafFrame.midY)))
                #expect(frame.contains(CGPoint(x: layout.iconFrame.midX, y: layout.iconFrame.midY)))
                #expect(frame.contains(CGPoint(x: size.width * 0.7, y: frame.midY)))
                #expect(frame.contains(CGPoint(x: size.width * 0.98, y: frame.midY)))
            }
            for y in stride(from: 0.5, to: size.height, by: 13) {
                for x in stride(from: 0.5, to: size.width, by: 13) {
                    let matches = layouts.filter { $0.interactiveFrame.contains(CGPoint(x: x, y: y)) }
                    #expect(matches.count == (x < trunkWidth ? 0 : 1))
                }
            }
            for boundary in layouts.dropFirst().map(\.bandFrame.minY) {
                let point = CGPoint(x: trunkWidth + 1, y: boundary)
                #expect(layouts.filter { $0.interactiveFrame.contains(point) }.count == 1)
            }
        }
    }

    @Test("Wind preserves leaf transparency and never paints over the fixed branch or trunk")
    func leafArtworkBounds() {
        for size in [CGSize(width: 720, height: 720), CGSize(width: 760, height: 760), CGSize(width: 1000, height: 720)] {
            for section in HomeNavigationSection.allCases {
                let layout = HomeNavigationLayout(section: section, canvasSize: size)
                let leaf = layout.leafFrame
                let cell = floor(min(leaf.width / 14, leaf.height / 9))
                let origin = CGPoint(x: leaf.midX - cell * 7, y: leaf.midY - cell * 4.5)
                let branchPoints = PixelLeafWind.baseRows.enumerated().flatMap { y, row in
                    row.enumerated().compactMap { x, pixel -> CGPoint? in
                        guard pixel == "B" else { return nil }
                        return CGPoint(x: origin.x + (CGFloat(x) + 0.5) * cell,
                            y: origin.y + (CGFloat(y) + 0.5) * cell)
                    }
                }
                for step in 0...24 {
                    let shape = layout.leafShape(elapsed: Double(step) / 6).path(in: leaf)
                    #expect(!shape.isEmpty)
                    #expect(branchPoints.allSatisfy { !shape.contains($0) })
                    for y in stride(from: 2.0, to: size.height, by: 20) {
                        for x in stride(from: 2.0, to: size.width * 0.25, by: 20) {
                            #expect(!shape.contains(CGPoint(x: x, y: y)))
                        }
                    }
                    #expect(!shape.contains(CGPoint(x: size.width * 0.7, y: leaf.midY)))
                    #expect(!shape.contains(CGPoint(x: size.width * 0.98, y: leaf.midY)))
                }
                let idleShape = layout.leafShape(elapsed: 0).path(in: leaf)
                for (y, row) in PixelLeafWind.baseRows.enumerated() {
                    for (x, pixel) in row.enumerated() {
                        let center = CGPoint(x: origin.x + (CGFloat(x) + 0.5) * cell,
                            y: origin.y + (CGFloat(y) + 0.5) * cell)
                        #expect(idleShape.contains(center) == (pixel == "G"))
                    }
                }
            }
        }
    }

    @Test("Icon artwork keeps transparent pixels and uses the actual animated frame")
    func iconArtworkBounds() {
        for section in HomeNavigationSection.allCases {
            let frame = HomeNavigationLayout(section: section, canvasSize: CGSize(width: 760, height: 760)).iconFrame
            let cell = floor(min(frame.width / 12, frame.height / 10))
            let origin = CGPoint(x: frame.midX - cell * 6, y: frame.midY - cell * 5)
            for step in 0...24 {
                let rows = PixelIcon(kind: section.icon, animationElapsed: Double(step) / 6).rows
                let shape = PixelSpriteShape(rows: rows, pixel: "W").path(in: frame)
                for (y, row) in rows.enumerated() {
                    for (x, pixel) in row.enumerated() {
                        let center = CGPoint(x: origin.x + (CGFloat(x) + 0.5) * cell,
                            y: origin.y + (CGFloat(y) + 0.5) * cell)
                        #expect(shape.contains(center) == (pixel == "W"))
                    }
                }
                #expect(!shape.contains(CGPoint(x: frame.minX, y: frame.minY)))
            }
        }
    }

    @Test("Icons retain fixed bounds and use faster motion")
    func iconFrames() {
        for kind in [PixelIcon.Kind.export, .history, .settings] {
            let idle = PixelIcon(kind: kind).rows
            let moving = PixelIcon(kind: kind, animationElapsed: 0.5).rows
            #expect(idle != moving)
            for time in stride(from: 0.0, through: 5.0, by: 0.05) {
                let rows = PixelIcon(kind: kind, animationElapsed: time).rows
                #expect(rows.count == 10)
                #expect(rows.allSatisfy { $0.count == 12 })
            }
        }
        let exportIdle = PixelIcon(kind: .export).rows
        #expect(PixelIcon(kind: .export, animationElapsed: 0.1).rows == exportIdle)
        #expect(PixelIcon(kind: .export, animationElapsed: 0.13).rows != exportIdle)
        #expect(PixelIcon(kind: .history, animationElapsed: 2).rows != PixelIcon(kind: .history).rows)
    }

    @Test("Pixel switches move the thumb without changing their dimensions")
    func pixelSwitchStates() {
        let off = PixelSwitchGlyph(isOn: false).rows
        let on = PixelSwitchGlyph(isOn: true).rows
        #expect(off != on)
        #expect(off.count == 8 && on.count == 8)
        #expect((off + on).allSatisfy { $0.count == 16 })
        #expect(coordinates(of: "W", in: off).count == coordinates(of: "W", in: on).count)
        #expect(coordinates(of: "W", in: off).allSatisfy { $0 % 16 < 8 })
        #expect(coordinates(of: "W", in: on).allSatisfy { $0 % 16 >= 8 })
    }

    private func coordinates(of pixel: Character, in rows: [String]) -> Set<Int> {
        Set(rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, character in character == pixel ? y * row.count + x : nil }
        })
    }

    private func differenceCount(_ lhs: [String], _ rhs: [String]) -> Int {
        zip(lhs.joined(), rhs.joined()).filter { $0 != $1 }.count
    }
}
