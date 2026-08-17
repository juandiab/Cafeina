// render.swift — rasterize an SVG app icon to PNGs at macOS icon sizes.
//
//   swift design/icon/render.swift <input.svg> <outdir> [size ...]
//
// Uses AppKit's built-in SVG support (NSImage(contentsOf:), CoreSVG) so the
// result matches what Xcode / macOS would produce from the same vector.
// Default sizes: 16 32 64 128 256 512 1024. Output: <outdir>/icon_<size>.png

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: swift render.swift <input.svg> <outdir> [size ...]\n".data(using: .utf8)!)
    exit(1)
}

let svgURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let sizes: [Int] = args.count > 3 ? args[3...].compactMap { Int($0) } : [16, 32, 64, 128, 256, 512, 1024]

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let image = NSImage(contentsOf: svgURL), image.isValid, image.size.width > 0 else {
    FileHandle.standardError.write("error: NSImage could not load \(svgURL.path) (unsupported SVG feature?)\n".data(using: .utf8)!)
    exit(2)
}

func render(_ image: NSImage, size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)   // 1 pt == 1 px, no @2x scaling games

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.shouldAntialias = true
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: .zero, operation: .sourceOver, fraction: 1.0,
               respectFlipped: true,
               hints: [.interpolation: NSImageInterpolation.high])
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for s in sizes {
    let rep = render(image, size: s)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("error: PNG encode failed at \(s)\n".data(using: .utf8)!)
        exit(3)
    }
    let out = outDir.appendingPathComponent("icon_\(s).png")
    do { try png.write(to: out) } catch {
        FileHandle.standardError.write("error: write failed \(out.path): \(error)\n".data(using: .utf8)!)
        exit(4)
    }
    print("wrote \(out.path) (\(s)x\(s))")
}
