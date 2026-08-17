import AppKit

// Renders two 2880x1800 App Store marketing images for Cafeina.
// usage: swift marketing.swift <icon1024.png> <menu-shot.png> <outdir>

let args = CommandLine.arguments
guard args.count == 4 else { print("usage: marketing.swift icon.png shot.png outdir"); exit(1) }
let iconURL = URL(fileURLWithPath: args[1])
let shotURL = URL(fileURLWithPath: args[2])
let outDir = URL(fileURLWithPath: args[3])

let W: CGFloat = 2880, H: CGFloat = 1800

let espresso = NSColor(red: 0.20, green: 0.12, blue: 0.07, alpha: 1)
let espressoDeep = NSColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1)
let crema = NSColor(red: 0.95, green: 0.66, blue: 0.23, alpha: 1)
let cream = NSColor(red: 1.0, green: 0.94, blue: 0.80, alpha: 1)
let creamDim = NSColor(red: 1.0, green: 0.94, blue: 0.80, alpha: 0.72)

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func draw(_ text: String, at p: NSPoint, font f: NSFont, color: NSColor, maxWidth: CGFloat? = nil, align: NSTextAlignment = .left, tracking: CGFloat = 0) {
    let para = NSMutableParagraphStyle()
    para.alignment = align
    para.lineBreakMode = .byWordWrapping
    var attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color, .paragraphStyle: para]
    if tracking != 0 { attrs[.kern] = tracking }
    let s = NSAttributedString(string: text, attributes: attrs)
    if let mw = maxWidth {
        let rect = NSRect(x: p.x, y: p.y, width: mw, height: 2000)
        let bounds = s.boundingRect(with: NSSize(width: mw, height: 2000), options: [.usesLineFragmentOrigin])
        // draw top-aligned at p.y (flipped: our context is not flipped, so compute)
        s.draw(with: NSRect(x: p.x, y: p.y - bounds.height, width: mw, height: bounds.height), options: [.usesLineFragmentOrigin])
        _ = rect
    } else {
        let size = s.size()
        s.draw(at: NSPoint(x: p.x, y: p.y - size.height))
    }
}

func background(_ ctx: CGContext) {
    let g = NSGradient(colors: [espresso, espressoDeep])!
    g.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -70)
    // soft crema glow top-right
    let glow = NSGradient(colorsAndLocations: (crema.withAlphaComponent(0.28), 0.0), (crema.withAlphaComponent(0.0), 1.0))!
    glow.draw(fromCenter: NSPoint(x: W * 0.78, y: H * 0.72), radius: 0, toCenter: NSPoint(x: W * 0.78, y: H * 0.72), radius: 1100, options: [])
    // subtle grain-free vignette bottom-left
    let v = NSGradient(colorsAndLocations: (NSColor.black.withAlphaComponent(0.25), 0.0), (NSColor.black.withAlphaComponent(0.0), 1.0))!
    v.draw(fromCenter: NSPoint(x: W * 0.1, y: H * 0.1), radius: 0, toCenter: NSPoint(x: W * 0.1, y: H * 0.1), radius: 1400, options: [])
}

func roundedImage(_ img: NSImage, in rect: NSRect, radius: CGFloat, shadow: Bool) {
    NSGraphicsContext.saveGraphicsState()
    if shadow {
        let sh = NSShadow()
        sh.shadowColor = NSColor.black.withAlphaComponent(0.55)
        sh.shadowBlurRadius = 60
        sh.shadowOffset = NSSize(width: 0, height: -30)
        sh.set()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    // hairline border
    NSColor.white.withAlphaComponent(0.12).setStroke()
    let p = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
    p.lineWidth = 2
    p.stroke()
}

func render(_ name: String, _ body: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    body(ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let url = outDir.appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote", url.path)
}

guard let icon = NSImage(contentsOf: iconURL), let shot = NSImage(contentsOf: shotURL) else { print("cannot load images"); exit(1) }

// ---------- Image 1: Hero ----------
render("shot2-hero-2880.png") { _ in
    background(NSGraphicsContext.current!.cgContext)
    // icon
    let iconSize: CGFloat = 620
    icon.draw(in: NSRect(x: 220, y: H - 260 - iconSize, width: iconSize, height: iconSize))
    // title
    draw("Cafeina", at: NSPoint(x: 900, y: H - 300), font: font(200, .bold), color: cream, tracking: -4)
    draw("Keep your Mac awake.\nFrom the menu bar.", at: NSPoint(x: 905, y: H - 560), font: font(96, .semibold), color: crema, maxWidth: 1400)
    draw("Timers · Until a time · App triggers\nPresenting mode · Battery-aware\nShortcuts & Siri · Global shortcut\nFree · Private · No tracking", at: NSPoint(x: 220, y: H - 1010), font: font(50, .medium), color: creamDim, maxWidth: 1150)
    // menu screenshot inset (right/bottom)
    let sw: CGFloat = 1240, shH: CGFloat = 775
    roundedImage(shot, in: NSRect(x: W - sw - 160, y: 130, width: sw, height: shH), radius: 32, shadow: true)
    // small footer
    draw("macOS 13 or later · Apple silicon & Intel", at: NSPoint(x: 220, y: 200), font: font(40, .medium), color: creamDim)
}

// ---------- Image 2: Features board ----------
render("shot3-features-2880.png") { _ in
    background(NSGraphicsContext.current!.cgContext)
    icon.draw(in: NSRect(x: 220, y: H - 190 - 260, width: 260, height: 260))
    draw("Everything a keep-awake app should do.", at: NSPoint(x: 540, y: H - 250), font: font(112, .bold), color: cream, maxWidth: 2200, tracking: -2)
    draw("And a few things the others don’t.", at: NSPoint(x: 545, y: H - 395), font: font(60, .medium), color: crema)

    let features: [(String, String, String)] = [
        ("timer", "Timers & until a time", "30 min, 1 h, 2 h, indefinitely, or until 6:00 PM. Countdown in the menu bar."),
        ("app.badge.checkmark", "Awake while apps run", "Pick apps — Zoom, Keynote, Terminal — that keep the Mac awake while they run."),
        ("display.2", "Awake while presenting", "Turns on when an external, mirrored, or AirPlay display connects."),
        ("battery.25percent", "Battery-aware", "Turn off automatically on battery power or below 20%. Or let the display sleep."),
        ("mic.and.signal.meter", "Shortcuts & Siri", "“Keep my Mac awake for 1 hour.” Build Focus-mode automations."),
        ("keyboard", "Global shortcut ⌃⌥⌘C", "Toggle from any app. Quiet notification when it turns off automatically."),
    ]
    let cols = 3, colW: CGFloat = 800, gapX: CGFloat = 60
    let startX: CGFloat = 220, top: CGFloat = H - 560, rowH: CGFloat = 480
    for (i, f) in features.enumerated() {
        let col = i % cols, row = i / cols
        let x = startX + CGFloat(col) * (colW + gapX)
        let y = top - CGFloat(row) * rowH
        // card
        let card = NSRect(x: x, y: y - 420, width: colW, height: 420)
        NSColor.white.withAlphaComponent(0.06).setFill()
        NSBezierPath(roundedRect: card, xRadius: 40, yRadius: 40).fill()
        NSColor.white.withAlphaComponent(0.10).setStroke()
        let bp = NSBezierPath(roundedRect: card, xRadius: 40, yRadius: 40); bp.lineWidth = 2; bp.stroke()
        // symbol
        if let sym = NSImage(systemSymbolName: f.0, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 84, weight: .semibold).applying(.init(hierarchicalColor: crema))) {
            let s = sym.size
            let scale = 110 / max(s.width, s.height)
            let r = NSRect(x: x + 50, y: y - 60 - s.height * scale, width: s.width * scale, height: s.height * scale)
            sym.draw(in: r)
        }
        draw(f.1, at: NSPoint(x: x + 50, y: y - 210), font: font(52, .bold), color: cream, maxWidth: colW - 100)
        draw(f.2, at: NSPoint(x: x + 50, y: y - 285), font: font(38, .regular), color: creamDim, maxWidth: colW - 100)
    }
    draw("Free · No accounts · No analytics · No network access · macOS 13+", at: NSPoint(x: 220, y: 130), font: font(40, .medium), color: creamDim)
}
