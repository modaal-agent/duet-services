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
