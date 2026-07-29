//
//  QuickAccessPinContextMenuBuilderTests.swift
//  SnapzyTests
//
//  Verifies the pin window context menu entry rules: "Copy Image" is always
//  present, "Copy Text" appears only when OCR produced non-whitespace text.
//

import AppKit
import XCTest
@testable import Snapzy

@MainActor
final class QuickAccessPinContextMenuBuilderTests: XCTestCase {
  private func makeEntries(
    ocrText: String?,
    onCopyImage: @escaping () -> Void = {},
    onCopyText: @escaping () -> Void = {}
  ) -> [QuickAccessPinContextMenuEntry] {
    QuickAccessPinContextMenuBuilder.makeEntries(
      ocrText: ocrText,
      onCopyImage: onCopyImage,
      onCopyText: onCopyText
    )
  }

  func testNilOCRTextProducesOnlyCopyImageEntry() {
    let entries = makeEntries(ocrText: nil)

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.title, L10n.QuickAccess.pinWindowCopyImage)
  }

  func testEmptyOCRTextProducesOnlyCopyImageEntry() {
    let entries = makeEntries(ocrText: "")

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.title, L10n.QuickAccess.pinWindowCopyImage)
  }

  func testWhitespaceOnlyOCRTextProducesOnlyCopyImageEntry() {
    let entries = makeEntries(ocrText: " \n\t  ")

    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.title, L10n.QuickAccess.pinWindowCopyImage)
  }

  func testNonEmptyOCRTextProducesCopyImageThenCopyText() {
    let entries = makeEntries(ocrText: "Hello world")

    XCTAssertEqual(entries.count, 2)
    XCTAssertEqual(entries[0].title, L10n.QuickAccess.pinWindowCopyImage)
    XCTAssertEqual(entries[1].title, L10n.QuickAccess.pinWindowCopyText)
  }

  func testEntriesUseExpectedSystemImages() {
    let entries = makeEntries(ocrText: "Hello world")

    XCTAssertEqual(entries[0].systemImage, "photo.on.rectangle")
    XCTAssertEqual(entries[1].systemImage, "text.viewfinder")
  }

  func testPerformActionInvokesMatchingClosure() {
    var didCopyImage = false
    var didCopyText = false
    let entries = makeEntries(
      ocrText: "Hello world",
      onCopyImage: { didCopyImage = true },
      onCopyText: { didCopyText = true }
    )

    entries[0].performAction()
    XCTAssertTrue(didCopyImage)
    XCTAssertFalse(didCopyText)

    entries[1].performAction()
    XCTAssertTrue(didCopyText)
  }

  func testMakeNSMenuBuildsItemsMatchingEntries() {
    let entries = makeEntries(ocrText: "Hello world")
    let menu = QuickAccessPinContextMenuBuilder.makeNSMenu(entries: entries)

    XCTAssertFalse(menu.autoenablesItems)
    XCTAssertEqual(menu.items.count, 2)
    XCTAssertEqual(menu.items.map(\.title), entries.map(\.title))
    XCTAssertTrue(menu.items.allSatisfy(\.isEnabled))
    XCTAssertTrue(menu.items.allSatisfy { $0.image != nil })
  }

  func testMenuItemActionInvokesEntryClosure() {
    var didCopyImage = false
    let entries = makeEntries(ocrText: nil, onCopyImage: { didCopyImage = true })
    let menu = QuickAccessPinContextMenuBuilder.makeNSMenu(entries: entries)

    guard let item = menu.items.first else { return XCTFail("Menu must contain the copy image item") }
    let wrapper = item.representedObject as? QuickAccessPinContextMenuAction
    XCTAssertNotNil(wrapper)
    XCTAssertTrue(item.target === wrapper)

    wrapper?.performMenuAction(item)
    XCTAssertTrue(didCopyImage)
  }
}
