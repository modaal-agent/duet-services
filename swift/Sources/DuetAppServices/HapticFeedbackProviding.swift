// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Outbound haptic-feedback action — fires the platform's impact generator
/// on behalf of the view layer. Composition-root-owned. View-side surfaces
/// consume it through the `\.hapticFeedback` SwiftUI Environment value;
/// node-side consumers take it as a constructor dependency.
///
/// sourcery: CreateMock
public protocol HapticFeedbackProviding: AnyObject {
  /// e.g. selection accents, card taps.
  func impactLight()
  /// e.g. a commit button.
  func impactMedium()
  /// e.g. a primary record/capture toggle.
  func impactHeavy()
  /// e.g. entry-animation landing accents.
  func impactSoft()
}

#if canImport(UIKit)

import SwiftUI
import UIKit

/// Real-singleton-backed default. Used as the fallback Environment value so
/// previews / standalone SwiftUI uses still fire haptics without explicit
/// wiring; production sets the instance the composition root constructed
/// (`SystemAppActions`).
public final class DefaultHapticFeedback: HapticFeedbackProviding {
  public init() {}

  // `UIImpactFeedbackGenerator` is `@MainActor` in the SDK; the port stays
  // nonisolated (its consumers are view-side taps, already on the main
  // thread), so each call states the isolation it relies on — the
  // `assumeIsolated` bracket turns the call-site contract from a comment
  // into a runtime precondition.

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
}

// MARK: - SwiftUI Environment

private struct HapticFeedbackKey: EnvironmentKey {
  // `EnvironmentKey.defaultValue` is a nonisolated static requirement, so it
  // cannot be main-actor isolated, and `any HapticFeedbackProviding` is not
  // `Sendable`. `DefaultHapticFeedback` has no stored properties — there is
  // no state for a second thread to see — so the value is shared safely.
  nonisolated(unsafe) static let defaultValue: HapticFeedbackProviding = DefaultHapticFeedback()
}

extension EnvironmentValues {
  /// The instance the SwiftUI tree uses to fire haptic feedback. Defaults to
  /// `DefaultHapticFeedback` (real generators); the composition root
  /// overrides it via `.environment(\.hapticFeedback, appActions)` on the
  /// root view so test surfaces can substitute a recording stub.
  public var hapticFeedback: HapticFeedbackProviding {
    get { self[HapticFeedbackKey.self] }
    set { self[HapticFeedbackKey.self] = newValue }
  }
}

#endif
