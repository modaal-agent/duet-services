// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// UIKit-bound (system singletons), so absent from the macOS host lane
// (whole-file-guarded by design).
#if canImport(UIKit)

import Foundation
import UIKit

/// Composite of the outbound system-singleton ports. The composition root
/// owns ONE instance and forwards it down the graph as narrow per-capability
/// protocols — a node that only opens URLs takes `URLOpening`, never the
/// composite.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Hand-write a double where a test needs one.
public protocol AppActionsProviding: URLOpening, HapticFeedbackProviding,
                                     PasteboardWriting, PasteboardReading {
}

/// Default implementation backed by the system singletons. Production wires
/// this; tests wire narrow per-protocol recorders.
///
/// `Sendable` because it holds no state — every member reaches a system
/// singleton directly. That is what lets a `Working` conformer hold one as a
/// stored property and forward the four ports to it instead of writing a
/// second implementation of each side effect.
public final class SystemAppActions: AppActionsProviding, Sendable {

  public init() {}

  // MARK: - URLOpening

  public func open(_ url: URL) {
    // `UIApplication.shared.open(_:)` requires the main thread — and is
    // `@MainActor`, which this nonisolated method is not, so each branch
    // states the isolation it has just established.
    if Thread.isMainThread {
      MainActor.assumeIsolated { UIApplication.shared.open(url) }
    } else {
      DispatchQueue.main.async {
        MainActor.assumeIsolated { UIApplication.shared.open(url) }
      }
    }
  }

  // MARK: - HapticFeedbackProviding
  // `UIImpactFeedbackGenerator` is main-thread API and `@MainActor` in the
  // SDK; call sites are view-side taps, already on the main thread — the
  // `assumeIsolated` bracket turns that from a comment into a runtime
  // precondition.

  public func impactLight() {
    MainActor.assumeIsolated { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
  }

  public func impactMedium() {
    MainActor.assumeIsolated { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
  }

  public func impactHeavy() {
    MainActor.assumeIsolated { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
  }

  public func impactSoft() {
    MainActor.assumeIsolated { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
  }

  // MARK: - PasteboardWriting / PasteboardReading

  public func write(string: String) {
    UIPasteboard.general.string = string
  }

  public func readString() -> String? {
    UIPasteboard.general.string
  }
}

#endif
