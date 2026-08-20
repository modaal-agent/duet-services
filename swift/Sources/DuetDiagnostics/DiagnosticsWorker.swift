// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetShells
import Foundation
import os

/// Crash-reporter hooks: the ONE seam a backend (Crashlytics, Sentry, …)
/// plugs into. The composition root sets them after configuring the backend;
/// nil hooks ⇒ every forward is a no-op — the worker stays fully functional
/// with no backend at all.
public struct DiagnosticsHooks: Sendable {
  let setUserID: (@Sendable (_ userID: String?) -> Void)?
  let setCustomValue: (@Sendable (_ value: Any?, _ key: String) -> Void)?
  let log: (@Sendable (_ message: String) -> Void)?
  let record: (@Sendable (_ error: Error, _ userInfo: [String: Any]?) -> Void)?

  public init(
    setUserID: (@Sendable (_: String?) -> Void)? = nil,
    setCustomValue: (@Sendable (_: Any?, _: String) -> Void)? = nil,
    log: (@Sendable (_: String) -> Void)? = nil,
    record: (@Sendable (_: Error, _: [String: Any]?) -> Void)? = nil
  ) {
    self.setUserID = setUserID
    self.setCustomValue = setCustomValue
    self.log = log
    self.record = record
  }
}

/// sourcery: CreateMock
@MainActor
public protocol DiagnosticsWorking: Working, Diagnostics {
  func setHooks(_ hooks: DiagnosticsHooks)
}

/// The one diagnostics worker, adopted at the composition root
/// (`host.adopt(diagnosticsWorker)`) so its lifetime is the app root's.
/// Backed by `os.Logger`; every entry also lands on the in-process `logs`
/// stream and (when set) the crash-reporter hooks.
///
/// Main-actor isolated via `DiagnosticsWorking` — the annotation sits on the
/// PROTOCOL, so the isolation reaches every consumer of the seam (the worker
/// rule in the duet framework's docs/workers.md). `hooks` needs no lock:
/// every access runs on the main actor, and the compiler checks it. The
/// hooks' closures stay `@Sendable` — a backend may capture objects it
/// services elsewhere.
@MainActor
public final class DiagnosticsWorker: DiagnosticsWorking {

  private var hooks: DiagnosticsHooks?
  private let logger: Logger
  private let _logs = PassthroughSubject<(level: LogLevel, message: String), Never>()

  /// `subsystem` follows os.Logger's reverse-DNS convention so Console.app
  /// filtering matches the app; the default is the host's bundle identifier.
  /// Pass a distinct subsystem when embedding (an app extension, a second
  /// host) or when there is no bundle to derive one from.
  public init(subsystem: String = Bundle.main.bundleIdentifier ?? "duet.diagnostics") {
    logger = Logger(subsystem: subsystem, category: "diagnostics")
  }

  // MARK: - Working

  /// No owned subscriptions — the bracket parks until host teardown; the
  /// port surface above stays live for the mount's duration.
  public func run() async {
    await untilCancelled()
  }

  // MARK: - DiagnosticsWorking

  public func setHooks(_ hooks: DiagnosticsHooks) {
    self.hooks = hooks
  }

  // MARK: - DiagnosticsLogging

  public func log(level: LogLevel, _ message: String) {
    let string = "\(level.rawValue): \(message)"
    hooks?.log?(string)
    logger.log(level: level.osLogType, "\(string, privacy: .public)")
    _logs.send((level: level, message: message))
  }

  public func exception(
    _ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String
  ) {
    var mergedInfo: [String: Any] = [
      "_file_": file,
      "_line_": line,
      "_function_": function,
    ]
    if let userInfo {
      mergedInfo.merge(userInfo, uniquingKeysWith: { a, _ in a })
    }

    hooks?.record?(error, mergedInfo)
    let string = "\(error.localizedDescription) (\(mergedInfo))"
    logger.error("\(string, privacy: .public)")
    _logs.send((level: .error, message: string))
  }

  // MARK: - DiagnosticsLogsObserving

  public var logs: AnyPublisher<(level: LogLevel, message: String), Never> {
    _logs.eraseToAnyPublisher()
  }

  // MARK: - Diagnostics

  public func setUserID(_ userID: String?) {
    hooks?.setUserID?(userID)
  }

  public func setCustomValue(_ value: Any?, forKey key: String) {
    hooks?.setCustomValue?(value, key)
  }
}

private extension LogLevel {
  var osLogType: OSLogType {
    switch self {
    case .info:
      return .default
    case .warn:
      return .info
    case .error:
      return .error
    case .fatal:
      return .fault
    }
  }
}
