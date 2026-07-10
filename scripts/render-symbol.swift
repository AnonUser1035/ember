#!/usr/bin/env swift
// Rasterizes an SF Symbol to a template-style PNG (black glyph on a
// transparent canvas) at an exact pixel size. Used by make-icons.sh to
// generate the menu-bar icons directly from the system's SF Symbols, so the
// glyph is pixel-identical to what `Image(systemName:)` would draw.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let pixelSize = Int(arguments[3]) else {
    FileHandle.standardError.write("usage: render-symbol.swift <symbol-name> <output.png> <pixel-size>\n".data(using: .utf8)!)
    exit(1)
}

let symbolName = arguments[1]
let outputURL = URL(fileURLWithPath: arguments[2])

guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
    FileHandle.standardError.write("Failed to load SF Symbol \(symbolName)\n".data(using: .utf8)!)
    exit(1)
}

// Symbol point size relative to the canvas — matches the visual weight
// NSStatusItem gives other apps' menu-bar glyphs (roughly 70% of the frame,
// leaving the same breathing room Apple's own template assets use).
let pointSize = CGFloat(pixelSize) * 0.72
let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
guard let sized = symbol.withSymbolConfiguration(config) else {
    FileHandle.standardError.write("Failed to apply symbol configuration\n".data(using: .utf8)!)
    exit(1)
}
sized.isTemplate = true

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write("Failed to allocate a \(pixelSize)x\(pixelSize) bitmap\n".data(using: .utf8)!)
    exit(1)
}
bitmap.size = NSSize(width: pixelSize, height: pixelSize)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let imageSize = sized.size
let origin = NSPoint(x: (CGFloat(pixelSize) - imageSize.width) / 2, y: (CGFloat(pixelSize) - imageSize.height) / 2)
NSColor.black.set()
sized.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG for \(outputURL.path)\n".data(using: .utf8)!)
    exit(1)
}

try pngData.write(to: outputURL)
print("Wrote \(outputURL.path) (\(pixelSize)x\(pixelSize)) from SF Symbol '\(symbolName)'")
