// Renders the TunnelBar app icon (1024x1024 PNG).
// Motif: dark squircle, receding tunnel arches, bright green connection beam.
import AppKit
import CoreGraphics

let size = 1024
let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// ── macOS-style squircle background ───────────────────────────────
let margin: CGFloat = 100
let bgRect = CGRect(x: margin, y: margin,
                    width: CGFloat(size) - margin*2, height: CGFloat(size) - margin*2)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let bgGrad = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rgba(28, 38, 52), rgba(10, 14, 20)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bgGrad,
    start: CGPoint(x: bgRect.midX, y: bgRect.maxY),
    end: CGPoint(x: bgRect.midX, y: bgRect.minY), options: [])

// ── receding tunnel arches ────────────────────────────────────────
let cx = bgRect.midX
let baseY = bgRect.minY + 150
let archColors: [(CGFloat, CGFloat)] = [   // (radius, alpha)
    (330, 0.95), (264, 0.55), (205, 0.35), (152, 0.22)
]
for (radius, alpha) in archColors {
    let p = CGMutablePath()
    p.addArc(center: CGPoint(x: cx, y: baseY), radius: radius,
             startAngle: 0, endAngle: .pi, clockwise: false)
    ctx.addPath(p)
    ctx.setStrokeColor(rgba(120, 200, 255, alpha))
    ctx.setLineWidth(radius > 300 ? 34 : 22)
    ctx.setLineCap(.round)
    ctx.strokePath()
}

// ── glowing green beam through the tunnel ─────────────────────────
let beamY = baseY + 60
// soft glow
for (w, a) in [(CGFloat(72), CGFloat(0.10)), (44, 0.22), (22, 0.5)] {
    ctx.setStrokeColor(rgba(70, 230, 130, a))
    ctx.setLineWidth(w)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: cx - 250, y: beamY))
    ctx.addLine(to: CGPoint(x: cx + 180, y: beamY))
    ctx.strokePath()
}
// core line
ctx.setStrokeColor(rgba(120, 255, 170, 1))
ctx.setLineWidth(12)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: cx - 250, y: beamY))
ctx.addLine(to: CGPoint(x: cx + 170, y: beamY))
ctx.strokePath()
// arrowhead
let ah = CGMutablePath()
ah.move(to: CGPoint(x: cx + 150, y: beamY + 52))
ah.addLine(to: CGPoint(x: cx + 240, y: beamY))
ah.addLine(to: CGPoint(x: cx + 150, y: beamY - 52))
ctx.addPath(ah)
ctx.setStrokeColor(rgba(120, 255, 170, 1))
ctx.setLineWidth(26)
ctx.setLineJoin(.round)
ctx.strokePath()
// origin dot
ctx.setFillColor(rgba(120, 255, 170, 1))
ctx.fillEllipse(in: CGRect(x: cx - 250 - 22, y: beamY - 22, width: 44, height: 44))

ctx.restoreGState()

// ── save PNG ──────────────────────────────────────────────────────
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
              ? CommandLine.arguments[1] : "icon-1024.png")
try! png.write(to: out)
print("wrote \(out.path)")
