import Foundation
import CoreGraphics
import AppKit

// Rebranding mascotte mavlos — v2 (riscritto, corretto):
//   1. carica il robot 3D ( Downloads/e2a16863d_generated_e0f59d37.png, sfondo quasi nero )
//   2. flood-fill dal bordo: mappa lo sfondo (il visore dark resta dentro la silhouette)
//   3. sfondo → trasparente; glow/ombre esterne → alfa semitrasparente
//      RI-PREMULTIPLICANDO i canali colore (nessun frangia bianca su tema chiaro)
//   4. edge smoothing (mediare 3×3 su alfa e RGB premolti)
//   5. scrive Assets/mavlos-mascot.png (1024) + @2x (512)
//   6. icona: squircle scuro con gradiente + robot → AppIcon.iconset/*
//
// Lancio dalla radice del progetto: swift Scripts/rebrand-mascot.swift

let src = ("~/Downloads/e2a16863d_generated_e0f59d37.png" as NSString).expandingTildeInPath
let root = FileManager.default.currentDirectoryPath
let assets = (root as NSString).appendingPathComponent("Assets")

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(
        data: nil, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

// ── 1 ▸ sorgente → buffer RGBA8 premultiplied ────────────────────────────────
guard let ns = NSImage(contentsOfFile: src),
      let tiff = ns.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let cg = rep.cgImage
else { fatalError("immagine sorgente illeggibile") }

let W = 1024, H = 1024, count = W * H
errMark("start OK")
let srcCtx = makeContext(W, H)
srcCtx.interpolationQuality = .high
srcCtx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
guard let srcData = srcCtx.makeImage()?.dataProvider?.data else { fatalError("buffer") }

var pix = [UInt8](repeating: 0, count: count * 4)
(srcData as Data).withUnsafeBytes { raw in
    pix.withUnsafeMutableBytes { dst in
        memcpy(dst.baseAddress, raw.baseAddress, count * 4)
    }
}
errMark("copy OK")

@inline(__always) func idx(_ x: Int, _ y: Int) -> Int { (y * W + x) * 4 }
func errMark(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
@inline(__always) func maxRGB(_ i: Int) -> Double {
    Double(max(pix[i], max(pix[i+1], pix[i+2])))
}

// ── 2 ▸ flood-fill dal bordo … maschera sfondo ───────────────────────────────
var bgMask = [Bool](repeating: false, count: count)
var stack: [Int] = []

@inline(__always) func dark(_ i: Int) -> Bool { maxRGB(i) / 255.0 < 0.30 }

for x in 0..<W {
    for y in [0, H - 1] {
        let i = idx(x, y)
        if !bgMask[i / 4] && dark(i) { bgMask[i / 4] = true; stack.append(i / 4) }
    }
}
for y in 0..<H {
    for x in [0, W - 1] {
        let i = idx(x, y)
        if !bgMask[i / 4] && dark(i) { bgMask[i / 4] = true; stack.append(i / 4) }
    }
}
while let p = stack.popLast() {
    let x = p % W, y = p / W
    for (nx, ny) in [(x+1, y), (x-1, y), (x, y+1), (x, y-1)] {
        guard nx >= 0, ny >= 0, nx < W, ny < H else { continue }
        let j = idx(nx, ny)
        if !bgMask[j / 4] && dark(j) { bgMask[j / 4] = true; stack.append(j / 4) }
    }
}
errMark("flood OK")

// ── 3 ▸ dilatazione 2px nella frangia anti-alias + alfa finale ───────────────
var dilated = bgMask
for _ in 0..<2 {
    var next = dilated
    for y in 0..<H {
        for x in 0..<W {
            let px = y * W + x
            if dilated[px] { continue }
            for (ax, ay) in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)] {
                guard ax >= 0, ay >= 0, ax < W, ay < H else { continue }
                if dilated[ay * W + ax] { next[px] = true; break }
            }
        }
    }
    dilated = next
}
errMark("dilate OK")

for k in 0..<count {
    let i = k * 4
    guard dilated[k] else { continue }              // robot: resta opaco, non toccare
    let m = maxRGB(i) / 255.0
    var a = min(1.0, m / 0.30)
    a = pow(a, 0.9)
    // ri-premolto: i canali colore scendono con l'alfa
    let r = Double(pix[i]) * a
    let g = Double(pix[i+1]) * a
    let b = Double(pix[i+2]) * a
    pix[i] = UInt8(r.rounded(.toNearestOrEven))
    pix[i+1] = UInt8(g.rounded(.toNearestOrEven))
    pix[i+2] = UInt8(b.rounded(.toNearestOrEven))
    pix[i+3] = UInt8((a * 255).rounded(.toNearestOrEven))
}
errMark("alfa OK")

// ── 4 ▸ blur 3×3 (due passate) su RGBA, per bordi morbidi ────────────────────
for pass in 0..<2 {
    let srcBuf = pix
    for y in 0..<H {
        for x in 0..<W {
            for ch in 0..<4 {
                var sum = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let ax = x + dx, ay = y + dy
                        guard ax >= 0, ay >= 0, ax < W, ay < H else { continue }
                        sum += Int(srcBuf[idx(ax, ay) + ch])
                    }
                }
                pix[idx(x, y) + ch] = UInt8((Double(sum) / 9).rounded(.toNearestOrEven))
            }
        }
    }
    errMark("blur \(pass) OK")
}

// ── scrivo il PNG della mascotte ─────────────────────────────────────────────
func writePNG(_ context: CGContext, _ size: Int, _ path: String) {
    let c = makeContext(size, size)
    c.interpolationQuality = .high
    c.draw(context.makeImage()!, in: CGRect(x: 0, y: 0, width: size, height: size))
    let outRep = NSBitmapImageRep(cgImage: c.makeImage()!)
    guard let data = outRep.representation(using: .png, properties: [:]) else { fatalError("png") }
    try! data.write(to: URL(fileURLWithPath: path))
    print("✓ \(path)")
}

let outCtx = makeContext(W, H)
pix.withUnsafeBytes { raw in
    memcpy(outCtx.data, raw.baseAddress, count * 4)
}
outCtx.flush()

writePNG(outCtx, 1024, (assets as NSString).appendingPathComponent("mavlos-mascot.png"))
writePNG(outCtx, 512, (assets as NSString).appendingPathComponent("mavlos-mascot@2x.png"))

// ── 6 ▸ icona: squircle scuro + robot ────────────────────────────────────────
let S = 1024
let ic = makeContext(S, S)
let inset = 64.0
let tile = CGFloat(S) - inset * 2
let radius = tile * 0.2237
let squircle = CGMutablePath()
squircle.addRoundedRect(in: CGRect(x: inset, y: inset, width: tile, height: tile),
                        cornerWidth: radius, cornerHeight: radius)
ic.addPath(squircle)
ic.clip()

let colors = [
    CGColor(srgbRed: 0x18/255.0, green: 0x1a/255.0, blue: 0x20/255.0, alpha: 1),
    CGColor(srgbRed: 0x10/255.0, green: 0x11/255.0, blue: 0x14/255.0, alpha: 1),
] as [CGColor]
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: colors as CFArray, locations: [0, 1])!
ic.drawLinearGradient(grad,
                      start: CGPoint(x: 0, y: CGFloat(S)), end: CGPoint(x: 0, y: 0),
                      options: [])

let glowColors = [
    CGColor(srgbRed: 0x69/255.0, green: 0xa8/255.0, blue: 1.0, alpha: 0.16),
    CGColor(srgbRed: 0x69/255.0, green: 0xa8/255.0, blue: 1.0, alpha: 0),
] as [CGColor]
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: glowColors as CFArray, locations: [0, 1])!
ic.drawRadialGradient(glow,
                      startCenter: CGPoint(x: CGFloat(S) / 2, y: CGFloat(S) * 0.82),
                      startRadius: 0,
                      endCenter: CGPoint(x: CGFloat(S) / 2, y: CGFloat(S) * 0.82),
                      endRadius: 420, options: [])

// robot centrato, occupa il 78% dell'altezza
let robotH = CGFloat(S) * 0.78
let ratio = CGFloat(W) / CGFloat(H)
let robotW = robotH * ratio
ic.interpolationQuality = .high
ic.draw(outCtx.makeImage()!, in: CGRect(
    x: (CGFloat(S) - robotW) / 2,
    y: (CGFloat(S) - robotH) / 2,
    width: robotW, height: robotH))

let iconImg = ic.makeImage()!

let iconset = (assets as NSString).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (name, size) in [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
] {
    writePNG(ic, size, (iconset as NSString).appendingPathComponent(name))
}
print("✓ iconset ricostruito")
