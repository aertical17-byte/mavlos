// Generates Assets/mavlos-mascot.png, Assets/AppIcon.iconset/*.png and,
// via iconutil, Assets/mavlos-icon.icns.
//
// The robot "Mav" is drawn fully in CoreGraphics: white shell, glossy black
// visor, glowing blue arched eyes, ear pods and a folder card. No emoji.
//
// Usage: swift Scripts/mascotgen.swift   (run from the project root)

import Foundation
import CoreGraphics
import AppKit

// MARK: - Paths

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// MARK: - Canvas

func makeContext(size: Int) -> CGContext {
    guard let ctx = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("cannot create CGContext") }
    return ctx
}

func writePNG(_ image: CGImage, _ url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed for \(url.lastPathComponent)")
    }
    try! data.write(to: url)
    print("wrote \(url.path)")
}

// MARK: - Colors (all coordinates live in a 1024-unit design space)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

enum C {
    static let white      = rgb(1, 1, 1)
    static let shellTop   = rgb(0.996, 1, 1)
    static let shellBot   = rgb(0.905, 0.925, 0.957)
    static let shellEdge  = rgb(0.55, 0.58, 0.64, 0.55)
    static let darkVisorA = rgb(0.075, 0.086, 0.11)
    static let darkVisorB = rgb(0.165, 0.185, 0.235)
    static let blue       = rgb(0.412, 0.659, 1)        // #69A8FF
    static let blueBright = rgb(0.72, 0.86, 1)
    static let purple     = rgb(0.647, 0.545, 0.918)    // #A58BEA
    static let green      = rgb(0.412, 0.772, 0.569)    // #69C591
    static let inkShadow  = rgb(0.09, 0.11, 0.16, 0.4)
}

// MARK: - Small drawing helpers

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linearFill(_ ctx: CGContext, in path: CGPath, _ top: CGColor, _ bottom: CGColor) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 1400), end: CGPoint(x: 512, y: -376),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

/// Stroke a path, optionally with layered glow passes around it.
func strokeGlow(_ ctx: CGContext, _ path: CGPath, _ width: CGFloat, _ color: CGColor,
                glowPasses: [(blur: CGFloat, alpha: CGFloat)] = []) {
    for pass in glowPasses {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(color.copy(alpha: pass.alpha)!)
        ctx.setShadow(offset: .zero, blur: pass.blur, color: color.copy(alpha: pass.alpha)!)
        ctx.setLineWidth(width + pass.blur * 0.55)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setShadow(offset: .zero, blur: 2, color: color.copy(alpha: 0.85)!)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Fill a path with a soft external glow.
func fillGlow(_ ctx: CGContext, _ path: CGPath, _ color: CGColor,
              passes: [(blur: CGFloat, alpha: CGFloat)], docore: CGColor? = nil) {
    for pass in passes {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setShadow(offset: .zero, blur: pass.blur, color: color.copy(alpha: pass.alpha)!)
        ctx.setFillColor(color.copy(alpha: max(pass.alpha, 0.02))!)
        ctx.fillPath()
        ctx.restoreGState()
    }
    if let core = docore {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(core)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// MARK: - Backdrop

func superellipse(_ rect: CGRect, n: CGFloat = 4.35) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let exp = 2 / n
    for i in 0...180 {
        let t = CGFloat(i) * .pi * 2 / 180
        let c = cos(t), s = sin(t)
        let x = cx + (c < 0 ? -1 : 1) * a * pow(abs(c), exp)
        let y = cy + (s < 0 ? -1 : 1) * b * pow(abs(s), exp)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func drawBackdrop(_ ctx: CGContext, iconSpace: Bool) {
    if iconSpace {
        let disc = superellipse(CGRect(x: 8, y: 8, width: 1008, height: 1008))
        ctx.saveGState()
        ctx.addPath(disc)
        ctx.clip()

        ctx.setFillColor(rgb(0.055, 0.07, 0.105))
        ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

        let blueGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [C.blue.copy(alpha: 0.32)!, C.blue.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        let purpleGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [C.purple.copy(alpha: 0.28)!, C.purple.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(blueGlow,
            startCenter: CGPoint(x: 250, y: 820), startRadius: 0,
            endCenter: CGPoint(x: 250, y: 820), endRadius: 580, options: [])
        ctx.drawRadialGradient(purpleGlow,
            startCenter: CGPoint(x: 820, y: 230), startRadius: 0,
            endCenter: CGPoint(x: 820, y: 230), endRadius: 580, options: [])

        // Warm studio spot behind the robot.
        let spot = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [rgb(0.30, 0.40, 0.62, 0.45), rgb(0.30, 0.40, 0.62, 0)] as CFArray,
            locations: [0, 1])!
        ctx.drawRadialGradient(spot,
            startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 470), endRadius: 470, options: [])

        ctx.restoreGState()
    } else {
        // Warm studio-light portrait backdrop.
        ctx.setFillColor(rgb(0.84, 0.86, 0.91))
        ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let base = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [rgb(0.95, 0.96, 0.99), rgb(0.82, 0.85, 0.90)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(base,
            start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        let keyLight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [rgb(1, 1, 1, 0.9), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(keyLight,
            startCenter: CGPoint(x: 512, y: 780), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 780), endRadius: 640, options: [])

        let blueGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [C.blue.copy(alpha: 0.16)!, C.blue.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        let purpleGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [C.purple.copy(alpha: 0.15)!, C.purple.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(blueGlow,
            startCenter: CGPoint(x: 120, y: 940), startRadius: 0,
            endCenter: CGPoint(x: 120, y: 940), endRadius: 480, options: [])
        ctx.drawRadialGradient(purpleGlow,
            startCenter: CGPoint(x: 940, y: 120), startRadius: 0,
            endCenter: CGPoint(x: 940, y: 120), endRadius: 480, options: [])
    }
}

// MARK: - Folder glyph on the card

func drawFolderGlyph(_ ctx: CGContext, card: CGRect) {
    let fw: CGFloat = 64, fh: CGFloat = 50
    let fx = card.midX - fw / 2
    let fy = card.minY + card.height * 0.42

    // Back tab
    let tab = rounded(CGRect(x: fx + 4, y: fy + fh - 20, width: fw * 0.55, height: 24), 6)
    linearFill(ctx, in: tab, rgb(0.29, 0.46, 0.83), rgb(0.25, 0.41, 0.76))

    // Body with glow
    let body = rounded(CGRect(x: fx, y: fy, width: fw, height: fh), 9)
    fillGlow(ctx, body, C.blue, passes: [(blur: 10, alpha: 0.5)])
    linearFill(ctx, in: body, C.blue, rgb(0.30, 0.54, 0.88))

    // Front slab (classic folder fold)
    let front = rounded(CGRect(x: fx - 3, y: fy - 2, width: fw + 6, height: fh * 0.58), 8)
    linearFill(ctx, in: front, rgb(0.49, 0.72, 1), rgb(0.36, 0.58, 0.95))

    // Label lines
    ctx.setFillColor(C.white.copy(alpha: 0.5)!)
    ctx.fill(CGRect(x: fx + 12, y: fy + 6, width: fw - 34, height: 6))
    ctx.fill(CGRect(x: fx + 12, y: fy + 18, width: fw - 24, height: 6))
}

// MARK: - The robot

func drawRobot(_ ctx: CGContext) {
    // Contact shadow on the floor
    let shadow = CGPath(ellipseIn: CGRect(x: 312, y: 116, width: 400, height: 58), transform: nil)
    ctx.saveGState()
    ctx.addPath(shadow)
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 30, color: C.inkShadow)
    ctx.setFillColor(rgb(0.09, 0.11, 0.16, 0.14))
    ctx.fillPath()
    ctx.restoreGState()

    // Feet
    for x in [398.0, 556.0] {
        let foot = rounded(CGRect(x: x, y: 158, width: 70, height: 46), 22)
        linearFill(ctx, in: foot, C.shellBot, rgb(0.82, 0.85, 0.90))
        ctx.saveGState()
        ctx.addPath(foot)
        ctx.setStrokeColor(C.shellEdge)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Torso
    let torso = rounded(CGRect(x: 372, y: 196, width: 280, height: 316), 88)
    linearFill(ctx, in: torso, C.shellTop, C.shellBot)
    ctx.saveGState()
    ctx.addPath(torso)
    ctx.setStrokeColor(C.shellEdge)
    ctx.setLineWidth(3)
    ctx.strokePath()
    ctx.restoreGState()

    // Folder card, gently rotated, floating in front of the chest
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 398)
    ctx.rotate(by: -0.06)
    let cardRect = CGRect(x: -72, y: -86, width: 144, height: 174)
    let card = rounded(cardRect, 18)
    ctx.saveGState()
    ctx.addPath(card)
    ctx.setShadow(offset: CGSize(width: 2, height: 10), blur: 20, color: rgb(0.08, 0.10, 0.16, 0.32))
    ctx.setFillColor(C.white)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(card)
    ctx.setStrokeColor(rgb(0.72, 0.75, 0.82, 0.8))
    ctx.setLineWidth(2)
    ctx.strokePath()
    ctx.restoreGState()
    drawFolderGlyph(ctx, card: cardRect)

    // Little status dot on the card
    let dot = CGPath(ellipseIn: CGRect(x: 40, y: 60, width: 14, height: 14), transform: nil)
    ctx.addPath(dot)
    ctx.setFillColor(C.green)
    ctx.fillPath()
    ctx.restoreGState()

    // Arms reaching the card corners
    let leftArm = CGMutablePath()
    leftArm.move(to: CGPoint(x: 394, y: 472))
    leftArm.addQuadCurve(to: CGPoint(x: 452, y: 330), control: CGPoint(x: 402, y: 376))
    strokeArm(ctx, leftArm, 42)

    let rightArm = CGMutablePath()
    rightArm.move(to: CGPoint(x: 630, y: 472))
    rightArm.addQuadCurve(to: CGPoint(x: 572, y: 330), control: CGPoint(x: 622, y: 376))
    strokeArm(ctx, rightArm, 42)

    // Hands gripping the card corners
    for hx in [452.0, 572.0] {
        let hand = CGPath(ellipseIn: CGRect(x: hx - 24, y: 306, width: 48, height: 48), transform: nil)
        linearFill(ctx, in: hand, C.shellTop, C.shellBot)
        ctx.saveGState()
        ctx.addPath(hand)
        ctx.setStrokeColor(C.shellEdge)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Neck
    let neck = rounded(CGRect(x: 478, y: 490, width: 68, height: 72), 26)
    linearFill(ctx, in: neck, rgb(0.82, 0.85, 0.90), rgb(0.75, 0.78, 0.85))

    // Antenna
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: 512, y: 760))
    stem.addLine(to: CGPoint(x: 512, y: 840))
    ctx.saveGState()
    ctx.addPath(stem)
    ctx.setStrokeColor(rgb(0.72, 0.76, 0.83))
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    let ball = CGPath(ellipseIn: CGRect(x: 486, y: 842, width: 52, height: 52), transform: nil)
    fillGlow(ctx, ball, C.blue, passes: [(blur: 26, alpha: 0.6), (blur: 12, alpha: 0.9)], docore: C.blueBright)
    let spec = CGPath(ellipseIn: CGRect(x: 500, y: 872, width: 14, height: 14), transform: nil)
    ctx.addPath(spec)
    ctx.setFillColor(C.white.copy(alpha: 0.9)!)
    ctx.fillPath()

    // Ear pods (half hidden behind the head)
    for (cx, cy) in [(302.0, 642.0), (722.0, 642.0)] {
        let pod = CGPath(ellipseIn: CGRect(x: cx - 42, y: cy - 46, width: 84, height: 92), transform: nil)
        linearFill(ctx, in: pod, C.shellTop, C.shellBot)
        ctx.saveGState()
        ctx.addPath(pod)
        ctx.setStrokeColor(C.shellEdge)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()
        let lens = CGPath(ellipseIn: CGRect(x: cx - 16, y: cy - 18, width: 32, height: 32), transform: nil)
        fillGlow(ctx, lens, C.blue, passes: [(blur: 16, alpha: 0.7), (blur: 7, alpha: 0.9)], docore: C.blueBright)
    }

    // Head
    let head = rounded(CGRect(x: 302, y: 526, width: 420, height: 236), 112)
    linearFill(ctx, in: head, C.shellTop, C.shellBot)
    ctx.saveGState()
    ctx.addPath(head)
    ctx.setStrokeColor(C.shellEdge)
    ctx.setLineWidth(3)
    ctx.strokePath()
    ctx.restoreGState()

    // Visor (glossy black)
    let visor = rounded(CGRect(x: 346, y: 558, width: 332, height: 160), 68)
    linearFill(ctx, in: visor, C.darkVisorB, C.darkVisorA) // lighter at top for gloss
    ctx.saveGState()
    ctx.addPath(visor)
    ctx.setStrokeColor(rgb(0, 0, 0, 0.65))
    ctx.setLineWidth(2.5)
    ctx.strokePath()
    ctx.restoreGState()

    // Diagonal reflections in the visor's top-left corner
    ctx.saveGState()
    ctx.addPath(visor)
    ctx.clip()
    ctx.translateBy(x: 408, y: 700)
    ctx.rotate(by: -0.30)
    ctx.setFillColor(C.white.copy(alpha: 0.085)!)
    ctx.addPath(rounded(CGRect(x: -60, y: 26, width: 150, height: 15), 7))
    ctx.fillPath()
    ctx.setFillColor(C.white.copy(alpha: 0.05)!)
    ctx.addPath(rounded(CGRect(x: -45, y: 4, width: 105, height: 8), 4))
    ctx.fillPath()
    ctx.restoreGState()

    // Faint blue bezel inside the visor
    let bezel = rounded(CGRect(x: 384, y: 592, width: 256, height: 112), 48)
    ctx.saveGState()
    ctx.addPath(visor)
    ctx.clip()
    ctx.addPath(bezel)
    ctx.setStrokeColor(C.blue.copy(alpha: 0.20)!)
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()

    // Eyes: glowing blue arcs squinting happily
    for ex in [430.0, 594.0] {
        let arc = CGMutablePath()
        arc.addArc(center: CGPoint(x: ex, y: 662), radius: 34,
                   startAngle: 0.30, endAngle: .pi - 0.30, clockwise: false)
        strokeGlow(ctx, arc, 15, rgb(0.62, 0.80, 1),
                   glowPasses: [(blur: 6, alpha: 0.55), (blur: 18, alpha: 0.4), (blur: 34, alpha: 0.3)])
    }

    // Mouth: soft welcoming smile
    let mouth = CGMutablePath()
    mouth.addArc(center: CGPoint(x: 512, y: 602), radius: 22,
                 startAngle: .pi + 0.42, endAngle: 2 * .pi - 0.42, clockwise: false)
    strokeGlow(ctx, mouth, 9, rgb(0.60, 0.71, 0.87), glowPasses: [(blur: 5, alpha: 0.35)])
}

// NOTE: kept tiny and single-purpose on purpose.

func strokeArm(_ ctx: CGContext, _ path: CGPath, _ width: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0.93, 0.95, 0.98))
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()
    // subtle shading line under the arm
    ctx.saveGState()
    ctx.translateBy(x: 0, y: -9)
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0.68, 0.72, 0.80, 0.85))
    ctx.setLineWidth(width * 0.4)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Composition

func render(size: Int, iconSpace: Bool) -> CGImage {
    let ctx = makeContext(size: size)
    ctx.saveGState()
    let k = CGFloat(size) / 1024
    ctx.scaleBy(x: k, y: k)

    drawBackdrop(ctx, iconSpace: iconSpace)

    if iconSpace {
        // Place the (smaller) robot in the squircle, low-center with floor glow.
        let floorGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [C.blue.copy(alpha: 0.12)!, C.blue.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(floorGlow,
            startCenter: CGPoint(x: 512, y: 210), startRadius: 0,
            endCenter: CGPoint(x: 512, y: 210), endRadius: 380, options: [])
        ctx.saveGState()
        ctx.translateBy(x: 512, y: 502)
        ctx.scaleBy(x: 0.72, y: 0.72)
        ctx.translateBy(x: -512, y: -505)
        drawRobot(ctx)
        ctx.restoreGState()
    } else {
        drawRobot(ctx)
    }

    ctx.restoreGState()
    return ctx.makeImage()!
}

// MARK: - Emit

let mascot = render(size: 1024, iconSpace: false)
writePNG(mascot, assets.appendingPathComponent("mavlos-mascot.png"))
writePNG(render(size: 512, iconSpace: false), assets.appendingPathComponent("mavlos-mascot@2x.png"))

let iconSpec: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (n, name) in iconSpec {
    writePNG(render(size: n, iconSpace: true), iconset.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("mavlos-icon.icns").path]
do {
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else {
        print("FALLBACK: AppIcon.iconset emitted but iconutil failed with status \(iconutil.terminationStatus)")
        exit(2)
    }
    print("wrote mavlos-icon.icns")
    exit(0)
}
