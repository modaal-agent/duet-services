// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Inbound URL dispatch — what the app's scene delegate calls when the system
/// opens a URL into the app, cold-launch context lists and warm opens alike.
///
/// sourcery: CreateMock
@MainActor
public protocol AppServiceURLHandling: AnyObject {
  /// Dispatch inbound URLs to the first registered handler that claims each
  /// one.
  func openURLs(_ urls: [URL])
}

public extension AppServiceURLHandling {
  func openURL(_ url: URL) {
    openURLs([url])
  }
}
