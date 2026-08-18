// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// The fakes, next to the ports (fakes-first): deterministic, reusable by
// worker tests and previews. DEBUG-only — release binaries never carry them;
// test builds are debug builds, so test targets see them.
#if DEBUG

import Foundation

/// Claims URLs by predicate, records what it handled.
public final class FakeURLHandler: URLHandling {
  public private(set) var handled: [URL] = []
  private let canHandle: (URL) -> Bool

  public init(canHandle: @escaping (URL) -> Bool = { _ in true }) {
    self.canHandle = canHandle
  }

  public func canHandleOpenUrl(_ url: URL) -> Bool { canHandle(url) }
  public func handleOpenUrl(_ url: URL) { handled.append(url) }
}

/// Records outbound opens instead of leaving the process.
public final class RecordingURLOpener: URLOpening {
  public private(set) var opened: [URL] = []
  public init() {}
  public func open(_ url: URL) { opened.append(url) }
}

/// Records haptic impacts by name, in call order.
public final class RecordingHapticFeedback: HapticFeedbackProviding {
  public private(set) var impacts: [String] = []
  public init() {}
  public func impactLight() { impacts.append("light") }
  public func impactMedium() { impacts.append("medium") }
  public func impactHeavy() { impacts.append("heavy") }
  public func impactSoft() { impacts.append("soft") }
}

/// An in-memory pasteboard.
public final class FakePasteboard: PasteboardWriting, PasteboardReading {
  public private(set) var written: [String] = []
  public var contents: String?

  public init() {}

  public func write(string: String) {
    written.append(string)
    contents = string
  }

  public func readString() -> String? { contents }
}

#if os(iOS)

import AVFoundation

/// Records session activations instead of touching the shared
/// `AVAudioSession`, and answers a fixed permission state. iOS-only, like the
/// port itself — the macOS host lane compiles neither.
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

#endif
