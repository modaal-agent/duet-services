// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// SwiftUI-bound, so absent from lanes without it (whole-file-guarded by
// design).
#if canImport(SwiftUI)

import Foundation
import SwiftUI

private struct HapticFeedbackKey: EnvironmentKey {
  // `EnvironmentKey.defaultValue` is a nonisolated static requirement, and
  // `any HapticFeedbackProviding` is not `Sendable`; `nil` holds no instance
  // for a second thread to see.
  nonisolated(unsafe) static let defaultValue: HapticFeedbackProviding? = nil
}

extension EnvironmentValues {
  /// The instance the SwiftUI tree fires haptic feedback through.
  ///
  /// The composition root constructs `OutboundAppServicesWorker`, adopts it
  /// on the host so its lifetime is the mount's, and assigns it here on the
  /// root view:
  ///
  /// ```swift
  /// let outboundAppServices = OutboundAppServicesWorker()
  /// host.adopt(outboundAppServices)
  /// rootView.environment(\.hapticFeedback, outboundAppServices)
  /// ```
  ///
  /// It is optional, and the default is `nil`, because this module constructs
  /// no implementation of its own: the adopted worker is the only one, and a
  /// subtree that runs outside a composition root — a preview, a standalone
  /// SwiftUI harness — has no worker to reach. Call sites spell that:
  /// `hapticFeedback?.impactLight()` fires in the app and does nothing in a
  /// preview.
  public var hapticFeedback: HapticFeedbackProviding? {
    get { self[HapticFeedbackKey.self] }
    set { self[HapticFeedbackKey.self] = newValue }
  }
}

#endif
