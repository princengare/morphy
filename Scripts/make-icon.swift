import AppKit

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let source = NSImage(contentsOf: sourceURL)!
var sourceRect = CGRect(origin: .zero, size: source.size)
let sourceImage = source.cgImage(forProposedRect: &sourceRect, context: nil, hints: nil)!
try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let representation = NSBitmapImageRep(cgImage: context.makeImage()!)
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try representation.representation(using: .png, properties: [:])!
            .write(to: destinationURL.appendingPathComponent(filename))
    }
}
