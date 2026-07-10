#!/usr/bin/env swift
// Rasterizes an SVG to a PNG at an exact pixel size, using AppKit's native
// SVG support (NSImage(contentsOf:)) — no external tools (rsvg-convert,
// Inkscape, ImageMagick) required. Used by make-icons.sh.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let pixelSize = Int(arguments[3]) else {
    FileHandle.standardError.write("usage: render-icon.swift <input.svg> <output.png> <pixel-size>\n".data(using: .utf8)!)
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let image = NSImage(contentsOf: inputURL) else {
    FileHandle.standardError.write("Failed to load \(inputURL.path)\n".data(using: .utf8)!)
    exit(1)
}

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
image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize), from: .zero, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG for \(outputURL.path)\n".data(using: .utf8)!)
    exit(1)
}

try pngData.write(to: outputURL)
print("Wrote \(outputURL.path) (\(pixelSize)x\(pixelSize))")
