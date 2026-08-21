// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// UIKit-bound (`UIBackgroundFetchResult` is the completion currency), so
// absent from the macOS host lane (whole-file-guarded by design).
#if canImport(UIKit)

import Foundation
import UIKit

/// Inbound push dispatch — what the app delegate calls with the APNS device
/// token and with each remote-notification payload.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Hand-write a double where a test needs one.
@MainActor
public protocol AppServiceNotificationHandling: AnyObject {
  func appDidRegisterForRemoteNotifications(deviceToken: Data)
  func appDidReceiveRemoteNotification(
    notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

#endif
