// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

// The composed dispatch surface: everything the platform hands INTO the app,
// as one type. An app's scene and app delegates store this and nothing else
// from this module, so a new inbound family (user activities, shortcut items,
// scene-state restoration) arrives as a new protocol composed in here rather
// than as a second stored property at every delegate.

#if canImport(UIKit)

/// NOT CreateMock-annotated: declared in a platform-conditional block, and a
/// generated mock is unconditional — the macOS host lane cannot compile the
/// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServiceHandling: AppServiceURLHandling,
                                    AppServiceNotificationHandling {
}

#else

/// NOT CreateMock-annotated: declared in a platform-conditional block, and a
/// generated mock is unconditional — the macOS host lane cannot compile the
/// UIKit branch's mock. Hand-write a double where a test needs one.
@MainActor
public protocol AppServiceHandling: AppServiceURLHandling {
}

#endif
