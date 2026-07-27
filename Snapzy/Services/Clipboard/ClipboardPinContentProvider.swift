//
//  ClipboardPinContentProvider.swift
//  Snapzy
//
//  Reads pinnable content (image or text) from the clipboard.
//  Images are extracted via a layered strategy (raw pasteboard data first,
//  NSImage readObjects fallback) and can be materialized as temp PNG files.
//

import AppKit
import Foundation
import UniformTypeIdentifiers
import os.log

nonisolated private let logger = Logger(subsystem: "Snapzy", category: "ClipboardPinContentProvider")

/// Content read from the clipboard for the pin flow. Images win over text.
enum ClipboardPinContent {
  case image(NSImage)
  case text(String)
}

/// Reads clipboard content for pinning and encodes images as temp PNG files.
///
/// Temp files are written to `TempCaptureManager.tempCaptureDirectory` and must
/// NOT be deleted immediately — orphaned files are cleaned up on next launch by
/// `TempCaptureManager.cleanupOrphanedFiles()`.
enum ClipboardPinContentProvider {

  /// Maximum characters kept when reading clipboard text; longer strings are truncated.
  static let maxTextLength = 50_000

  // MARK: - Read

  /// Read pinnable content from the pasteboard, preferring images over text.
  /// Returns nil when neither a decodable image nor non-empty text is available.
  static func read(from pasteboard: NSPasteboard = .general) -> ClipboardPinContent? {
    if let image = readImage(from: pasteboard) {
      return .image(image)
    }
    if let text = readText(from: pasteboard) {
      return .text(text)
    }
    DiagnosticLogger.shared.log(.info, .clipboard, "Clipboard pin read found no usable content")
    return nil
  }

  // MARK: - Temp PNG

  /// Encode an image as PNG into the temp capture directory so downstream
  /// consumers can reference a file. Returns nil if encoding or the write fails.
  static func writeTempPNG(_ image: NSImage) -> URL? {
    guard let data = pngData(from: image) else {
      logger.error("ClipboardPinContentProvider: failed to encode image as PNG")
      DiagnosticLogger.shared.log(.error, .clipboard, "Clipboard pin PNG encode failed")
      return nil
    }

    let tempDir = TempCaptureManager.shared.tempCaptureDirectory
    let fileURL = tempDir.appendingPathComponent("Snapzy_Clipboard_\(UUID().uuidString).png")

    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try data.write(to: fileURL, options: .atomic)
      return fileURL
    } catch {
      logger.error("ClipboardPinContentProvider: temp PNG write failed: \(error.localizedDescription)")
      DiagnosticLogger.shared.logError(
        .clipboard,
        error,
        "Clipboard pin temp PNG write failed",
        context: ["fileName": fileURL.lastPathComponent]
      )
      return nil
    }
  }

  // MARK: - Image extraction

  private static let rawImageTypes: [NSPasteboard.PasteboardType] = [
    .png,
    .tiff,
    NSPasteboard.PasteboardType(UTType.jpeg.identifier),
    NSPasteboard.PasteboardType(UTType.gif.identifier),
    NSPasteboard.PasteboardType(UTType.bmp.identifier),
    NSPasteboard.PasteboardType(UTType.heic.identifier),
    NSPasteboard.PasteboardType(UTType.webP.identifier),
  ]

  private static func readImage(from pasteboard: NSPasteboard) -> NSImage? {
    // Prefer raw image data on the first pasteboard item so the original
    // pixels are kept instead of a promise-backed conversion.
    if let firstItem = pasteboard.pasteboardItems?.first {
      for rawType in rawImageTypes {
        guard let data = firstItem.data(forType: rawType),
              let image = NSImage(data: data),
              isValidImage(image) else { continue }
        return image
      }
    }

    // Fallback: let AppKit resolve any readable image representation.
    if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
       let image = images.first(where: isValidImage) {
      return image
    }

    return nil
  }

  private static func isValidImage(_ image: NSImage) -> Bool {
    image.size.width > 0 && image.size.height > 0
  }

  // MARK: - Text extraction

  private static func readText(from pasteboard: NSPasteboard) -> String? {
    guard let raw = pasteboard.string(forType: .string) else { return nil }

    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.count > maxTextLength else { return trimmed }

    DiagnosticLogger.shared.log(
      .info,
      .clipboard,
      "Clipboard pin text truncated",
      context: ["originalLength": "\(trimmed.count)", "maxLength": "\(maxTextLength)"]
    )
    return String(trimmed.prefix(maxTextLength))
  }

  // MARK: - Encoding

  private static func pngData(from image: NSImage) -> Data? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = image.size
    return bitmapRep.representation(using: .png, properties: [:])
  }
}
