import CWebP
import Foundation
@preconcurrency import ImageIO

struct WebPEncoder {
    func encode(image: CGImage, source: CGImageSource, to url: URL, request: ImageConversionRequest) throws {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let orientedImage: CGImage
        if orientation != 1 {
            guard let transformed = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(image.width, image.height)
            ] as CFDictionary) else {
                throw ConversionError.decoderFailure("Could not apply image orientation.")
            }
            orientedImage = transformed
        } else {
            orientedImage = image
        }
        guard orientedImage.width <= 16_383, orientedImage.height <= 16_383 else {
            throw ConversionError.encoderFailure("This image exceeds WebP's maximum dimensions.")
        }
        let colorSpace = request.preserveColorProfile && orientedImage.colorSpace?.model == .rgb
            ? orientedImage.colorSpace!
            : CGColorSpace(name: CGColorSpace.sRGB)!
        let stride = orientedImage.width * 4
        var pixels = [UInt8](repeating: 0, count: stride * orientedImage.height)
        let encoded = try pixels.withUnsafeMutableBytes { bytes -> Data in
            guard let context = CGContext(data: bytes.baseAddress, width: orientedImage.width,
                height: orientedImage.height, bitsPerComponent: 8, bytesPerRow: stride,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue) else {
                throw ConversionError.encoderFailure("Could not prepare WebP pixels.")
            }
            context.draw(orientedImage, in: CGRect(x: 0, y: 0, width: orientedImage.width, height: orientedImage.height))
            let rgba = bytes.bindMemory(to: UInt8.self)
            // Core Graphics provides premultiplied alpha; libwebp expects straight RGBA.
            for offset in Swift.stride(from: 0, to: rgba.count, by: 4) {
                let alpha = Int(rgba[offset + 3])
                if alpha > 0 && alpha < 255 {
                    for channel in 0..<3 {
                        rgba[offset + channel] = UInt8(min(255, (Int(rgba[offset + channel]) * 255 + alpha / 2) / alpha))
                    }
                }
            }
            var output: UnsafeMutablePointer<UInt8>?
            let quality = Float((request.qualityPreset.encoderQuality(for: .webP) ?? 0.85) * 100)
            let count = WebPEncodeRGBA(rgba.baseAddress, Int32(orientedImage.width),
                Int32(orientedImage.height), Int32(stride), quality, &output)
            guard count > 0, let output else {
                throw ConversionError.encoderFailure("libwebp could not encode this image.")
            }
            defer { WebPFree(output) }
            return Data(bytes: output, count: count)
        }
        let result = try attachProfile(to: encoded, profile: request.preserveColorProfile ? colorSpace.copyICCData() as Data? : nil)
        try result.write(to: url)
    }

    private func attachProfile(to encoded: Data, profile: Data?) throws -> Data {
        guard let profile else { return encoded }
        return try encoded.withUnsafeBytes { bytes in
            var input = WebPData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress, size: encoded.count)
            guard let mux = WebPMuxCreate(&input, 1) else {
                throw ConversionError.encoderFailure("Could not create WebP metadata container.")
            }
            defer { WebPMuxDelete(mux) }
            let status = profile.withUnsafeBytes { profileBytes in
                var chunk = WebPData(bytes: profileBytes.bindMemory(to: UInt8.self).baseAddress, size: profile.count)
                return WebPMuxSetChunk(mux, "ICCP", &chunk, 1)
            }
            guard status == WEBP_MUX_OK else {
                throw ConversionError.metadataFailure("Could not attach the WebP color profile.")
            }
            var output = WebPData()
            guard WebPMuxAssemble(mux, &output) == WEBP_MUX_OK, let pointer = output.bytes else {
                throw ConversionError.encoderFailure("Could not assemble WebP output.")
            }
            defer { WebPFree(UnsafeMutableRawPointer(mutating: pointer)) }
            return Data(bytes: pointer, count: output.size)
        }
    }
}
