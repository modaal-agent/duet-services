// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// iOS-bound (`AVAudioSession` has no macOS counterpart), so absent from the
// macOS host lane (whole-file-guarded by design).
#if os(iOS)

import AVFoundation
import Foundation

/// The audio-session seam: activate / deactivate the shared `AVAudioSession`
/// singleton for playback and recording, in lieu of direct
/// `AVAudioSession.sharedInstance()` calls scattered through view shells.
/// First-class on purpose — the receipt from apps that grew AV surfaces is
/// that this seam matters exactly then, and retrofitting it is the expensive
/// path. Until the app has an AV surface, nothing consumes it; the default
/// below is inert until called.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Hand-write a double where a test needs one.
public protocol AudioSessionConfiguring: AnyObject {
  /// Configure the shared session for audible playback and activate it.
  /// Idempotent — safe to call repeatedly.
  func activatePlayback()

  /// Configure the shared session for `.playAndRecord` and activate it.
  /// Idempotent. Throws if the underlying session rejects the toggle.
  func activateRecording() throws

  /// Deactivate the shared session, notifying other apps so ducked
  /// background audio resumes.
  func deactivate()

  /// Current record-permission state, so callers can branch (granted →
  /// record, undetermined → request, denied → surface UX).
  ///
  /// iOS 17 and up: `AVAudioApplication` is where recording permission lives,
  /// and `AVAudioSession`'s equivalent is deprecated. This package floors at
  /// iOS 16, so the two permission members carry the availability rather than
  /// the package holding every consumer to the deprecated spelling. An app
  /// whose deployment target is 17 or higher calls them with no availability
  /// check, and conforms with no annotation of its own.
  @available(iOS 17, *)
  var recordPermission: AVAudioApplication.recordPermission { get }

  /// Prompt the OS permission alert. The handler arrives on a non-main
  /// thread per the system signature; dispatch before touching UI.
  @available(iOS 17, *)
  func requestRecordPermission(_ handler: @escaping @Sendable (Bool) -> Void)
}

/// System-singleton-backed default.
public final class SystemAudioSession: AudioSessionConfiguring {
  public init() {}

  public func activatePlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }

  public func activateRecording() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .default)
    try session.setActive(true)
  }

  public func deactivate() {
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
  }

  @available(iOS 17, *)
  public var recordPermission: AVAudioApplication.recordPermission {
    AVAudioApplication.shared.recordPermission
  }

  @available(iOS 17, *)
  public func requestRecordPermission(_ handler: @escaping @Sendable (Bool) -> Void) {
    AVAudioApplication.requestRecordPermission(completionHandler: handler)
  }
}

#endif
