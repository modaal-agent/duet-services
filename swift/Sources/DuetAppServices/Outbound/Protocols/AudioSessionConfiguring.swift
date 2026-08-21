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
/// path. Until the app has an AV surface, nothing consumes it;
/// `OutboundAppServicesWorker`'s implementation is inert until called.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// `DuetAppServicesTestSupport` ships `FakeAudioSession` for tests that need
/// a double.
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

#endif
