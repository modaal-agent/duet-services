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

/// The one outbound worker, adopted at the composition root
/// (`host.adopt(outboundAppServices)`): everything the app asks OF the system
/// — opening URLs, the pasteboard, haptics, the audio session, and the two
/// permission prompts.
///
/// The composition root owns ONE instance and forwards it down the graph as
/// narrow per-capability ports — a feature that opens a URL takes
/// `URLOpening`, never the composite.
///
/// Every side effect is implemented HERE, in the worker, rather than in a
/// helper the worker forwards to: a system call that carries a threading rule
/// (`UIApplication.open(_:)` and the impact generators are main-thread API)
/// has one home, and the isolation each call establishes is stated at the
/// call itself.
///
/// It is nonisolated, and every member is a direct call into a system
/// singleton, so there is no state for isolation to guard. The `Working`
/// bracket gives its lifetime to the mount and gives future state (a cached
/// authorization status, an audio-interruption subscription) a `run()` to
/// live in without restructuring the composition root.
public final class OutboundAppServicesWorker: OutboundAppServicesWorking {

  public init() {}

  // MARK: - Working

  /// No owned subscriptions — the bracket parks until host teardown; every
  /// member is a direct call into a system singleton.
  public func run() async {
    await untilCancelled()
  }

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
    // `UIPasteboard.general.string` is safe from any thread.
    UIPasteboard.general.string = string
  }

  public func readString() -> String? {
    UIPasteboard.general.string
  }

  // MARK: - AudioSessionConfiguring

  // `AVAudioSession.sharedInstance()` calls are thread-safe; failures (another
  // app holding the session, a route change mid-call) are dropped via `try?`
  // per the port's best-effort contract, except on `activateRecording()`,
  // whose caller branches on the throw.

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
