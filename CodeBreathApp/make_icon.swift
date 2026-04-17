// Generate CodeBreath app icon: rounded-square gradient card with SF Symbol "lungs.fill".
// Outputs PNGs at all required sizes into an .iconset/ directory, ready for iconutil.

import AppKit
import CoreGraphics
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Pairs: (logical size, scale-suffix, filename)
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

// Gradient colors: purple → blue, matches the accent used in app.
let colorTop = NSColor(red: 0.56, green: 0.40, blue: 0.95, alpha: 1.0)  // purple
let colorBot = NSColor(red: 0.22, green: 0.52, blue: 0.95, alpha: 1.0)  // blue

func drawIcon(size px: Int) -> NSImage {
    let size = CGFloat(px)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Rounded square mask (~22.37% radius, matches macOS Big Sur app icon squircle).
    let radius = size * 0.2237
    let inset: CGFloat = size * 0.1  // safe-area, mimic macOS icon margins
    let cardRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = CGPath(roundedRect: cardRect, cornerWidth: radius * 0.78, cornerHeight: radius * 0.78, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Gradient fill.
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [colorTop.cgColor, colorBot.cgColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
        options: []
    )

    // Inner glossy highlight at top.
    ctx.saveGState()
    let highlightRect = CGRect(x: cardRect.minX, y: cardRect.midY, width: cardRect.width, height: cardRect.height / 2)
    let highlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor.white.withAlphaComponent(0.18).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.addRect(highlightRect)
    ctx.clip()
    ctx.drawLinearGradient(
        highlight,
        start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.midX, y: cardRect.midY),
        options: []
    )
    ctx.restoreGState()

    // SF Symbol "lungs.fill" centered, rendered in white.
    let symbolSize = size * 0.52
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold, scale: .large)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "lungs.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let w = symbol.size.width
        let h = symbol.size.height
        let drawRect = NSRect(
            x: (size - w) / 2,
            y: (size - h) / 2,
            width: w,
            height: h
        )
        symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

for (px, name) in sizes {
    let img = drawIcon(size: px)
    savePNG(img, to: "\(outDir)/\(name)")
    print("wrote \(name) @ \(px)px")
}

print("done")
