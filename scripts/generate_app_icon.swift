#!/usr/bin/env swift
import AppKit
import CoreGraphics

/// One-shot: renders LLLB on deep blue, 1024×1024 PNG for iOS AppIcon.
let w = 1024
let h = 1024
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/AppIcon.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: w,
    pixelsHigh: h,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("bitmap rep failed\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
defer { NSGraphicsContext.restoreGraphicsState() }

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("graphics context failed\n", stderr)
    exit(1)
}
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high
// Bitmap Y-flip so text reads upright
ctx.cgContext.translateBy(x: 0, y: CGFloat(h))
ctx.cgContext.scaleBy(x: 1, y: -1)

// Deep blue background (#0f2847)
NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.28, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: h)).fill()

let text = "LLLB"
let fontSize: CGFloat = 300
// Explicit Latin sans so “L” is not confused with Greek/Cyrillic in some heavy system fonts.
let font = NSFont(name: "HelveticaNeue-Bold", size: fontSize)
    ?? NSFont(name: "Arial-BoldMT", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
let nsText = text as NSString
let ts = nsText.size(withAttributes: attrs)
let x = (CGFloat(w) - ts.width) / 2
let y = (CGFloat(h) - ts.height) / 2
nsText.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("png encode failed\n", stderr)
    exit(1)
}

try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote", outPath)
