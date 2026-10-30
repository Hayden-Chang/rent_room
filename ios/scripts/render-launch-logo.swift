import AppKit
import SwiftUI

// Export the approved native logo composition for the code-free system launch screen.
// Usage: swift render-launch-logo.swift <original-png> <output-png>
let arguments = CommandLine.arguments
guard arguments.count == 3, let source = NSImage(contentsOfFile: arguments[1]) else {
    fatalError("Expected an existing source PNG and an output PNG path")
}
try MainActor.assumeIsolated {
    let logo = Image(nsImage: source)
        .resizable()
        .scaledToFit()
        .frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    let renderer = ImageRenderer(content: logo)
    renderer.scale = 3
    renderer.colorMode = .nonLinear
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("Native logo rendering failed")
    }
    try png.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
}
