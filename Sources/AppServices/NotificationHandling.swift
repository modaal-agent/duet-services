// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// UIKit-bound (`UIBackgroundFetchResult` is the completion currency), so
// absent from the macOS host lane (whole-file-guarded by design).
#if canImport(UIKit)

import UIKit

/// The inbound push contract: one handler per notification family,
/// registered on `AppServicesWorker` with a priority. Token registration
/// fans out to every handler; payload dispatch goes to the first handler
/// that claims it.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Hand-write a double where a test needs one.
@MainActor
public protocol NotificationHandling: AnyObject {
  func appDidRegisterForRemoteNotifications(deviceToken: Data)

  func canHandleRemoteNotification(
    notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool
  func handleRemoteNotification(
    notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

#endif
