//
//  ClipboardTextImageRenderer.swift
//  Snapzy
//
//  Renders plain clipboard text into a Retina-quality NSImage for pinning.
//  Fixed light background keeps pinned text readable regardless of the
//  system appearance.
//

import AppKit
import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: "Snapzy", category: "ClipboardTextImageRenderer")

/// Renders plain text as a pinnable image at 2x pixel density.
enum ClipboardTextImageRenderer {

  // MARK: - Layout constants (exposed for tests)

  /// Maximum width available for text layout, in points (excludes padding).
  static let maxTextWidth: CGFloat = 720
  /// Maximum canvas width including padding, in points.
  static let maxCanvasWidth: CGFloat = 1600
  /// Maximum canvas height including padding, in points; taller text is clipped.
  static let maxCanvasHeight: CGFloat = 2000
  /// Padding around the text on every edge, in points.
  static let textPadding: CGFloat = 20
  /// Pixel density multiplier for the backing bitmap (Retina).
  static let renderScale: CGFloat = 2

  private static let fontSize: CGFloat = 14
  private static let lineHeightMultiple: CGFloat = 1.4

  // MARK: - Render

  /// Render plain text into an NSImage backed by a 2x bitmap.
  /// Returns nil when the text is empty after trimming whitespace.
  static func render(_ text: String) -> NSImage? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let attributedText = NSAttributedString(string: trimmed, attributes: textAttributes())

    // Measure wrapped text against the max text width.
    let boundingRect = attributedText.boundingRect(
      with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let textSize = NSSize(
      width: min(ceil(boundingRect.width), maxTextWidth),
      height: ceil(boundingRect.height)
    )

    let canvasSize = NSSize(
      width: min(textSize.width + textPadding * 2, maxCanvasWidth),
      height: min(textSize.height + textPadding * 2, maxCanvasHeight)
    )

    let pixelWidth = max(1, Int(ceil(canvasSize.width * renderScale)))
    let pixelHeight = max(1, Int(ceil(canvasSize.height * renderScale)))

    guard let bitmapRep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixelWidth,
      pixelsHigh: pixelHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else {
      logger.error("ClipboardTextImageRenderer: failed to create bitmap rep")
      DiagnosticLogger.shared.log(.error, .clipboard, "Clipboard text render bitmap creation failed")
      return nil
    }
    bitmapRep.size = canvasSize

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
      logger.error("ClipboardTextImageRenderer: failed to create graphics context")
      DiagnosticLogger.shared.log(.error, .clipboard, "Clipboard text render graphics context failed")
      return nil
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphicsContext

    // Fixed light background so the pinned text stays readable in dark mode.
    NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    // Text taller than the canvas is clipped at the bottom edge.
    let textRect = NSRect(
      x: textPadding,
      y: canvasSize.height - textPadding - textSize.height,
      width: canvasSize.width - textPadding * 2,
      height: textSize.height
    )
    attributedText.draw(
      with: textRect,
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    let image = NSImage(size: canvasSize)
    image.addRepresentation(bitmapRep)
    return image
  }

  // MARK: - Attributes

  private static func textAttributes() -> [NSAttributedString.Key: Any] {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.lineHeightMultiple = lineHeightMultiple

    return [
      .font: NSFont.systemFont(ofSize: fontSize),
      // Fixed dark text on the fixed light background; labelColor would flip
      // to white under dark appearance and become unreadable.
      .foregroundColor: NSColor.black.withAlphaComponent(0.85),
      .paragraphStyle: paragraphStyle,
    ]
  }
}
