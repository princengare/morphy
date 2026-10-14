import Foundation
import Testing
@testable import MorphyApp

@Suite("Pixel navigation and animation")
@MainActor
struct PixelPresentationTests {
    @Test("Home bands cover the full height without gaps or overlapping interiors")
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
        #expect(Set(sections.map(\.windRate)).count == 3)
        #expect(Set(sections.map(\.windPhase)).count == 3)
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
                    rate: section.windRate, phase: section.windPhase)
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
