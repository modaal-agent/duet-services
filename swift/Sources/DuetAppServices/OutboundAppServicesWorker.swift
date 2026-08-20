// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// iOS-bound, so absent from the macOS host lane (whole-file-guarded by
// design): the composite carries `AudioSessionConfiguring`, whose members
// name `AVAudioApplication`, and the two prompts reach UIKit,
// UserNotifications and AppTrackingTransparency. The ports themselves are
// platform-neutral and stay compiled on every lane — this file is the
// implementation half.
#if os(iOS)

import AVFoundation
import AppTrackingTransparency
import DuetShells
import Foundation
import UIKit
import UserNotifications

/// Composite of the outbound ports: everything the app asks OF the system —
/// opening URLs, the pasteboard, haptics, the audio session, and the two
/// permission prompts.
///
/// The composition root owns ONE instance, adopts it
/// (`host.adopt(outboundAppServicesWorker)`), and forwards it down the graph
/// as narrow per-capability protocols — a node that opens URLs takes
/// `URLOpening`, never the composite.
///
/// It is a `Working` so its lifetime is the mount's, bracketed like the
/// inbound registry worker beside it: one adoption call covers both halves of
/// the app-services boundary, and state that later wants a lifetime (a cached
/// authorization status, an audio-interruption subscription) has a `run()` to
/// live in without restructuring the composition root.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Depend on the narrow ports, each of which has its own generated double.
public protocol OutboundAppServicesWorking: Working, AppActionsProviding,
                                            AppTrackingAuthorizationRequesting,
                                            PushNotificationAuthorizationRequesting,
                                            AudioSessionConfiguring {
}

/// Default implementation backed by the system singletons. Production wires
/// this; tests wire narrow per-protocol doubles.
///
/// The URL, pasteboard, haptic and audio-session members forward to
/// `SystemAppActions` and `SystemAudioSession`, so each side effect —
/// including the main-thread discipline `UIApplication.open(_:)` and the
/// impact generators require — has one implementation in this package rather
/// than a second copy here.
public final class OutboundAppServicesWorker: OutboundAppServicesWorking {

  private let appActions = SystemAppActions()
  private let audioSession = SystemAudioSession()

  public init() {}

  // MARK: - Working

  /// No owned subscriptions — the bracket parks until host teardown; every
  /// member is a direct call into a system singleton.
  public func run() async {
    await untilCancelled()
  }

  // MARK: - URLOpening

  public func open(_ url: URL) {
    appActions.open(url)
  }

  // MARK: - HapticFeedbackProviding

  public func impactLight() {
    appActions.impactLight()
  }

  public func impactMedium() {
    appActions.impactMedium()
  }

  public func impactHeavy() {
    appActions.impactHeavy()
  }

  public func impactSoft() {
    appActions.impactSoft()
  }

  // MARK: - PasteboardWriting / PasteboardReading

  public func write(string: String) {
    appActions.write(string: string)
  }

  public func readString() -> String? {
    appActions.readString()
  }

  // MARK: - AudioSessionConfiguring

  public func activatePlayback() {
    audioSession.activatePlayback()
  }

  public func activateRecording() throws {
    try audioSession.activateRecording()
  }

  public func deactivate() {
    audioSession.deactivate()
  }

  @available(iOS 17, *)
  public var recordPermission: AVAudioApplication.recordPermission {
    audioSession.recordPermission
  }

  @available(iOS 17, *)
  public func requestRecordPermission(_ handler: @escaping @Sendable (Bool) -> Void) {
    audioSession.requestRecordPermission(handler)
  }

  // MARK: - AppTrackingAuthorizationRequesting

  public func requestTrackingAuthorizationIfNeeded() {
    // The status check is what makes the call idempotent: requesting while
    // the answer is already recorded returns it without showing anything,
    // and the guard keeps that fact at the call site rather than in the
    // system's behaviour.
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
    ATTrackingManager.requestTrackingAuthorization { _ in }
  }

  // MARK: - PushNotificationAuthorizationRequesting

  public func requestPushAuthorizationIfNeeded() {
    // `UNUserNotificationCenter.current()` is re-read inside the completion
    // rather than captured: the handler escapes, and the accessor returns
    // the same singleton either way.
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .notDetermined:
        UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Self.registerForRemoteNotifications()
          }
      case .authorized, .ephemeral, .provisional:
        Self.registerForRemoteNotifications()
      case .denied:
        break
      @unknown default:
        break
      }
    }

  }

  /// `registerForRemoteNotifications()` is main-thread API and `@MainActor`
  /// in the SDK, and both call sites above arrive on whichever queue the
  /// notification centre answered on — so the hop is unconditional and the
  /// `assumeIsolated` bracket states the isolation it establishes.
  private static func registerForRemoteNotifications() {
    DispatchQueue.main.async {
      MainActor.assumeIsolated { UIApplication.shared.registerForRemoteNotifications() }
    }
  }
}

#endif
