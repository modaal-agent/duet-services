// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// The AppServices product's shared test double for its one
// platform-conditional port. This product is linked by test targets only —
// a production target never declares it, so the fake stays out of release
// binaries by link topology rather than by a build-configuration gate.
//
// This is the only hand-written double in the package: every unconditional
// port carries `sourcery: CreateMock`, so a consumer's mock-generation lane
// emits its double (`URLHandlingMock`, `PasteboardWritingMock`, …) beside
// its other mocks. `AudioSessionConfiguring` cannot be annotated — the
// generated file is unconditional, and the macOS host lane cannot compile a
// mock over iOS-only types.
//
// Follow-up: the mock-generation templates gain support for
// platform-conditional ports and `@available` members; this double is
// generated once that lands, and this product retires with it.

import AppServices
import Foundation

#if os(iOS)

import AVFoundation

/// Records session activations instead of touching the shared
/// `AVAudioSession`, and answers a fixed permission state. iOS-only, like the
/// port itself — the macOS host lane compiles neither. Platform-conditional,
/// so it is hand-written: an annotation here would generate an unconditional
/// mock the other platform's lane cannot compile.
public final class FakeAudioSession: AudioSessionConfiguring {
  public private(set) var activations: [String] = []
  public var recordPermissionRequestResult = true

  private let permission: Any?

  /// Availability-free construction — an iOS 16 consumer exercises the three
  /// activation members with the permission answer left at `.granted`.
  public init() {
    permission = nil
  }

  @available(iOS 17, *)
  public init(recordPermission: AVAudioApplication.recordPermission = .granted) {
    permission = recordPermission
  }

  public func activatePlayback() { activations.append("playback") }
  public func activateRecording() throws { activations.append("recording") }
  public func deactivate() { activations.append("deactivate") }

  @available(iOS 17, *)
  public var recordPermission: AVAudioApplication.recordPermission {
    (permission as? AVAudioApplication.recordPermission) ?? .granted
  }

  @available(iOS 17, *)
  public func requestRecordPermission(_ handler: @escaping @Sendable (Bool) -> Void) {
    handler(recordPermissionRequestResult)
  }
}

#endif
