// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Outbound URL-open action — opens a URL in whichever external handler the
/// system picks (the browser for `https`, another app's universal-link
/// handler, the mail client for `mailto:`, …). Composition-root-owned and
/// injected into nodes so the side-effect is testable: tests substitute a
/// recorder for the URL handed to `open(_:)`.
///
/// Sibling to `URLHandling`, which sits on the *inbound* side of the
/// app-services boundary (URLs the OS opens *into* the app). `URLOpening`
/// is for app-initiated outbound opens.
///
/// sourcery: CreateMock
public protocol URLOpening: AnyObject {
  /// Asks the system to open `url`. The default (`OutboundAppServicesWorker`) calls
  /// `UIApplication.shared.open(url)`.
  func open(_ url: URL)
}
