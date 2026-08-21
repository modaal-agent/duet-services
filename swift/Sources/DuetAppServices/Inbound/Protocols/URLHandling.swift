// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The inbound URL contract: one handler per URL family (deep links, invite
/// links, sign-in callbacks, …), registered on `InboundAppServicesWorker` with a
/// priority. Handlers claim a URL via `canHandleOpenUrl` and get exactly the
/// ones they claimed.
///
/// sourcery: CreateMock
public protocol URLHandling: AnyObject {
  func canHandleOpenUrl(_ url: URL) -> Bool
  func handleOpenUrl(_ url: URL)
}
