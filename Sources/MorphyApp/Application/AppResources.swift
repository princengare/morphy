import AppKit
import Foundation

extension Bundle {
    static var morphyResources: Bundle {
        if let resourceURL = Bundle.main.resourceURL,
           let bundled = Bundle(url: resourceURL.appendingPathComponent("Morphy_MorphyApp.bundle")) {
            return bundled
        }
        return .module
    }
}

@MainActor
enum AppImages {
    static let monochromeLogo = load("logo")
    static let colorLogo = load("logo-color")

    private static func load(_ name: String) -> NSImage {
        guard let url = Bundle.morphyResources.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing bundled morphy image: \(name)")
        }
        return image
    }
}
