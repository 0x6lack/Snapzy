//
//  QuickAccessPinContextMenuBuilder.swift
//  Snapzy
//
//  Builds the right-click context menu for pinned screenshot windows.
//

import AppKit

enum QuickAccessPinContextMenuEntry {
  case action(
    title: String,
    systemImage: String,
    action: () -> Void
  )

  var title: String {
    switch self {
    case .action(let title, _, _):
      return title
    }
  }

  var systemImage: String {
    switch self {
    case .action(_, let systemImage, _):
      return systemImage
    }
  }

  func performAction() {
    switch self {
    case .action(_, _, let action):
      action()
    }
  }
}

@MainActor
enum QuickAccessPinContextMenuBuilder {
  /// Builds the entries for a pin window context menu. "Copy Image" is always
  /// present; "Copy Text" appears only when OCR produced non-whitespace text.
  static func makeEntries(
    ocrText: String?,
    onCopyImage: @escaping () -> Void,
    onCopyText: @escaping () -> Void
  ) -> [QuickAccessPinContextMenuEntry] {
    var entries: [QuickAccessPinContextMenuEntry] = [
      .action(
        title: L10n.QuickAccess.pinWindowCopyImage,
        systemImage: "photo.on.rectangle",
        action: onCopyImage
      ),
    ]

    let trimmedText = ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedText.isEmpty {
      entries.append(
        .action(
          title: L10n.QuickAccess.pinWindowCopyText,
          systemImage: "text.viewfinder",
          action: onCopyText
        )
      )
    }

    return entries
  }

  static func makeNSMenu(entries: [QuickAccessPinContextMenuEntry]) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    for entry in entries {
      switch entry {
      case .action(let title, let systemImage, let action):
        let wrapper = QuickAccessPinContextMenuAction(action)
        let item = NSMenuItem(
          title: title,
          action: #selector(QuickAccessPinContextMenuAction.performMenuAction(_:)),
          keyEquivalent: ""
        )
        item.target = wrapper
        item.isEnabled = true
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        // NSMenuItem.target is weak; representedObject keeps the wrapper alive.
        item.representedObject = wrapper
        menu.addItem(item)
      }
    }

    return menu
  }
}

final class QuickAccessPinContextMenuAction: NSObject {
  private let action: () -> Void

  init(_ action: @escaping () -> Void) {
    self.action = action
    super.init()
  }

  @objc func performMenuAction(_ sender: NSMenuItem) {
    action()
  }
}
