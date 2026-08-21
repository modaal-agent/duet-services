// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The App Tracking Transparency prompt.
///
/// The signature is platform-neutral — no framework type appears in it — so a
/// feature that asks for the permission compiles and runs its logical tests
/// on every lane this package builds on, and takes a generated double there.
/// The implementation is iOS-bound and lives in
/// `OutboundAppServicesWorker`.
///
/// The system shows the prompt once per install: a request made while the
/// status is anything other than "not determined" returns the standing answer
/// and displays nothing. Depend on this port rather than calling the tracking
/// manager, so a feature's test asserts the request instead of driving a
/// system alert.
///
/// sourcery: CreateMock
public protocol AppTrackingAuthorizationRequesting: AnyObject {
  /// Shows the prompt when the status is not yet determined; does nothing
  /// otherwise. Fire-and-forget — read `ATTrackingManager`'s status once the
  /// prompt resolves if the app needs the answer.
  func requestTrackingAuthorizationIfNeeded()
}
