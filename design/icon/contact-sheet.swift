// contact-sheet.swift — lay out icon candidates at 512/128/64/32/16 on light and dark
// backgrounds (plus 4x nearest-neighbour blow-ups of the 32 and 16 px renders).
//
//   swift design/icon/contact-sheet.swift <out.png> <a.svg> [<b.svg> ...]
//
// Each SVG is rasterized through NSImage (CoreSVG) at every target size, exactly like
// render.swift, so what you see is what macOS will draw.

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: swift contact-sheet.swift <out.png> <a.svg> [more.svg ...]\n".data(using: .utf8)!)
    exit(1)
}
let outURL = URL(fileURLWithPath: args[1])
let svgs = args[2...].map { URL(fileURLWithPath: $0) }

let sizes = [512, 128, 64, 32, 16]
let zoomSizes = [32, 16]
let zoom = Int(ProcessInfo.processInfo.environment["ZOOM"] ?? "") ?? 4   // ZOOM=8 for closer inspection
let margin = 48
let gap = 28
let labelH = 34
let rowH = 512 + labelH + gap

func rasterize(_ image: NSImage, size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
               operation: .sourceOver, fraction: 1, respectFlipped: true,
               hints: [.interpolation: NSImageInterpolation.high])
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

struct Candidate { let name: String; let renders: [Int: NSBitmapImageRep] }

var candidates: [Candidate] = []
for url in svgs {
    guard let img = NSImage(contentsOf: url), img.isValid else {
        FileHandle.standardError.write("error: cannot load \(url.path)\n".data(using: .utf8)!)
        exit(2)
    }
    var r: [Int: NSBitmapImageRep] = [:]
    for s in Set(sizes + zoomSizes) { r[s] = rasterize(img, size: s) }
    candidates.append(Candidate(name: url.deletingPathExtension().lastPathComponent, renders: r))
}

// column geometry: actual-size run, then zoomed run
let actualRunW = sizes.reduce(0, +) + gap * (sizes.count - 1)
let zoomRunW = zoomSizes.map { $0 * zoom }.reduce(0, +) + gap * (zoomSizes.count - 1)
let panelW = margin + actualRunW + gap * 2 + zoomRunW + margin
let panelH = margin + labelH + rowH * candidates.count + margin / 2
let sheetW = panelW * 2
let sheetH = panelH

let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: sheetW, pixelsHigh: sheetH,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
sheet.size = NSSize(width: sheetW, height: sheetH)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: sheet)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
// flip so y grows downward like a design tool
cg.translateBy(x: 0, y: CGFloat(sheetH))
cg.scaleBy(x: 1, y: -1)

func draw(_ rep: NSBitmapImageRep, at p: CGPoint, scale: Int = 1) {
    let w = CGFloat(rep.pixelsWide * scale), h = CGFloat(rep.pixelsHigh * scale)
    guard let cgimg = rep.cgImage else { return }
    cg.saveGState()
    cg.interpolationQuality = scale == 1 ? .high : .none
    // un-flip for image drawing
    cg.translateBy(x: p.x, y: p.y + h)
    cg.scaleBy(x: 1, y: -1)
    cg.draw(cgimg, in: CGRect(x: 0, y: 0, width: w, height: h))
    cg.restoreGState()
}

func label(_ text: String, at p: CGPoint, color: NSColor, size: CGFloat = 18, bold: Bool = false) {
    let font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size, weight: .regular)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: text, attributes: attrs)
    cg.saveGState()
    cg.translateBy(x: p.x, y: p.y + size * 1.2)
    cg.scaleBy(x: 1, y: -1)
    str.draw(at: .zero)
    cg.restoreGState()
}

let panels: [(bg: NSColor, fg: NSColor, title: String)] = [
    (NSColor(calibratedWhite: 0.93, alpha: 1), NSColor(calibratedWhite: 0.25, alpha: 1), "Light  (Finder / Dock light)"),
    (NSColor(calibratedWhite: 0.13, alpha: 1), NSColor(calibratedWhite: 0.80, alpha: 1), "Dark  (Finder / Dock dark)"),
]

for (pi, panel) in panels.enumerated() {
    let ox = CGFloat(pi * panelW)
    cg.setFillColor(panel.bg.cgColor)
    cg.fill(CGRect(x: ox, y: 0, width: CGFloat(panelW), height: CGFloat(panelH)))
    label(panel.title, at: CGPoint(x: ox + CGFloat(margin), y: CGFloat(margin) - 10), color: panel.fg, size: 22, bold: true)

    for (ci, cand) in candidates.enumerated() {
        let rowY = CGFloat(margin + labelH + ci * rowH)
        label(cand.name, at: CGPoint(x: ox + CGFloat(margin), y: rowY), color: panel.fg, size: 18, bold: true)
        var x = ox + CGFloat(margin)
        let baseline = rowY + CGFloat(labelH) + 512   // bottom-align icons on the 512 baseline
        for s in sizes {
            let rep = cand.renders[s]!
            draw(rep, at: CGPoint(x: x, y: baseline - CGFloat(s)))
            label("\(s)", at: CGPoint(x: x, y: baseline + 6), color: panel.fg.withAlphaComponent(0.7), size: 13)
            x += CGFloat(s + gap)
        }
        x += CGFloat(gap)
        for s in zoomSizes {
            let rep = cand.renders[s]!
            draw(rep, at: CGPoint(x: x, y: baseline - CGFloat(s * zoom)), scale: zoom)
            label("\(s) ×\(zoom)", at: CGPoint(x: x, y: baseline + 6), color: panel.fg.withAlphaComponent(0.7), size: 13)
            x += CGFloat(s * zoom + gap)
        }
    }
}

ctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = sheet.representation(using: .png, properties: [:]) else { exit(3) }
try! png.write(to: outURL)
print("wrote \(outURL.path) (\(sheetW)x\(sheetH))")
