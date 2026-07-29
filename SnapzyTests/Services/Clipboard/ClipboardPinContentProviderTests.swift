//
//  ClipboardPinContentProviderTests.swift
//  SnapzyTests
//
//  Unit tests for ClipboardPinContentProvider read priority, text handling,
//  and temp PNG materialization.
//

import AppKit
import XCTest
@testable import Snapzy

@MainActor
final class ClipboardPinContentProviderTests: XCTestCase {

  private var pasteboard: NSPasteboard!

  override func setUp() {
    super.setUp()
    pasteboard = NSPasteboard(name: NSPasteboard.Name("SnapzyTests.ClipboardPin.\(UUID().uuidString)"))
    pasteboard.clearContents()
  }

  override func tearDown() {
    pasteboard.releaseGlobally()
    pasteboard = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func makeTestImage(width: Int = 10, height: Int = 10) throws -> NSImage {
    let cgImage = try XCTUnwrap(TestImageFactory.solidColor(width: width, height: height))
    return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
  }

  private func makePNGData(width: Int = 10, height: Int = 10) throws -> Data {
    let cgImage = try XCTUnwrap(TestImageFactory.solidColor(width: width, height: height))
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    return try XCTUnwrap(bitmapRep.representation(using: .png, properties: [:]))
  }

  // MARK: - Read

  func testRead_imageOnPasteboard_returnsImage() throws {
    pasteboard.setData(try makePNGData(), forType: .png)

    let content = ClipboardPinContentProvider.read(from: pasteboard)

    guard case .image(let image) = content else {
      XCTFail("Expected .image, got \(String(describing: content))")
      return
    }
    XCTAssertGreaterThan(image.size.width, 0)
    XCTAssertGreaterThan(image.size.height, 0)
  }

  func testRead_plainText_returnsTrimmedText() {
    pasteboard.setString("  Hello Snapzy \n", forType: .string)

    let content = ClipboardPinContentProvider.read(from: pasteboard)

    guard case .text(let text) = content else {
      XCTFail("Expected .text, got \(String(describing: content))")
      return
    }
    XCTAssertEqual(text, "Hello Snapzy")
  }

  func testRead_imageAndText_prefersImage() throws {
    pasteboard.setData(try makePNGData(), forType: .png)
    pasteboard.setString("fallback text", forType: .string)

    let content = ClipboardPinContentProvider.read(from: pasteboard)

    guard case .image = content else {
      XCTFail("Expected image to win over text, got \(String(describing: content))")
      return
    }
  }

  func testRead_emptyPasteboard_returnsNil() {
    XCTAssertNil(ClipboardPinContentProvider.read(from: pasteboard))
  }

  func testRead_whitespaceOnlyText_returnsNil() {
    pasteboard.setString("   \n\t  ", forType: .string)

    XCTAssertNil(ClipboardPinContentProvider.read(from: pasteboard))
  }

  func testRead_textLongerThanMax_truncatesToMaxLength() {
    let longText = String(repeating: "a", count: ClipboardPinContentProvider.maxTextLength + 100)
    pasteboard.setString(longText, forType: .string)

    let content = ClipboardPinContentProvider.read(from: pasteboard)

    guard case .text(let text) = content else {
      XCTFail("Expected .text, got \(String(describing: content))")
      return
    }
    XCTAssertEqual(text.count, ClipboardPinContentProvider.maxTextLength)
  }

  // MARK: - Temp PNG

  func testWriteTempPNG_producesNonEmptyPNGFile() throws {
    let image = try makeTestImage()

    let url = try XCTUnwrap(ClipboardPinContentProvider.writeTempPNG(image))
    defer { try? FileManager.default.removeItem(at: url) }

    XCTAssertEqual(url.pathExtension, "png")
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    let data = try Data(contentsOf: url)
    XCTAssertFalse(data.isEmpty)
    XCTAssertNotNil(NSImage(data: data))
  }
}
