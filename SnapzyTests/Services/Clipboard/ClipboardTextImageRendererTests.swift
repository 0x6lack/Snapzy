//
//  ClipboardTextImageRendererTests.swift
//  SnapzyTests
//
//  Unit tests for ClipboardTextImageRenderer sizing and pixel density.
//

import AppKit
import XCTest
@testable import Snapzy

@MainActor
final class ClipboardTextImageRendererTests: XCTestCase {

  func testRender_plainText_producesImageWithPositiveSize() throws {
    let image = try XCTUnwrap(ClipboardTextImageRenderer.render("Hello, Snapzy!"))

    XCTAssertGreaterThan(image.size.width, 0)
    XCTAssertGreaterThan(image.size.height, 0)
  }

  func testRender_emptyString_returnsNil() {
    XCTAssertNil(ClipboardTextImageRenderer.render(""))
  }

  func testRender_whitespaceOnlyString_returnsNil() {
    XCTAssertNil(ClipboardTextImageRenderer.render("   \n\t  "))
  }

  func testRender_longMultilineText_staysWithinCanvasLimits() throws {
    let longLine = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 20)
    let longText = Array(repeating: longLine, count: 100).joined(separator: "\n")

    let image = try XCTUnwrap(ClipboardTextImageRenderer.render(longText))

    XCTAssertLessThanOrEqual(image.size.width, ClipboardTextImageRenderer.maxCanvasWidth)
    XCTAssertLessThanOrEqual(image.size.height, ClipboardTextImageRenderer.maxCanvasHeight)
  }

  func testRender_backingRepresentation_usesRenderScalePixelDensity() throws {
    let image = try XCTUnwrap(ClipboardTextImageRenderer.render("Scale check"))
    let bitmapRep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)

    let scale = ClipboardTextImageRenderer.renderScale
    XCTAssertEqual(CGFloat(bitmapRep.pixelsWide), image.size.width * scale, accuracy: 1)
    XCTAssertEqual(CGFloat(bitmapRep.pixelsHigh), image.size.height * scale, accuracy: 1)
  }
}
