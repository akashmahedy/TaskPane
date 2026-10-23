import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.28, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 208, yRadius: 208).fill()
        let tiles: [(NSRect, NSColor)] = [
            (NSRect(x: 225, y: 538, width: 255, height: 270), .white),
            (NSRect(x: 524, y: 538, width: 275, height: 270), NSColor(calibratedRed: 0.36, green: 0.57, blue: 1, alpha: 1)),
            (NSRect(x: 225, y: 272, width: 255, height: 222), NSColor(calibratedRed: 0.36, green: 0.57, blue: 1, alpha: 1)),
            (NSRect(x: 524, y: 272, width: 275, height: 222), .white)
        ]
        for (rect, color) in tiles {
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 32, yRadius: 32).fill()
        }
        NSColor(calibratedRed: 0.36, green: 0.57, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 225, y: 188, width: 574, height: 34), xRadius: 17, yRadius: 17).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}

// Store PNG representations in the standard ICNS container without iconservices.
// This also works inside CI sandboxes where iconutil cannot contact its service.
func bigEndian(_ value: UInt32) -> Data {
    var number = value.bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var chunks = Data()
for (kind, filename) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
                         ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
                         ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
                         ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: output.appendingPathComponent(filename))
    chunks.append(Data(kind.utf8)); chunks.append(bigEndian(UInt32(png.count + 8))); chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(bigEndian(UInt32(chunks.count + 8))); icon.append(chunks)
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
try icon.write(to: destination, options: .atomic)
