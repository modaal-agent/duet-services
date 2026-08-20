// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import Foundation

public enum LogLevel: String, Sendable {
  case info = "ℹ️"
  case warn = "⚠️"
  case error = "❗️"
  case fatal = "🛑"
}

/// The logging port. Feature nodes and workers depend on this, never on a
/// concrete logger — the composition root owns the one `DiagnosticsWorker`
/// and hands this narrow surface down the dependency graph.
///
/// The whole port stack is `@MainActor`: the isolation lives on the
/// protocols so it reaches every consumer, and the worker satisfies the
/// requirements without a witness-isolation gap (the worker rule in the
/// duet framework's docs/workers.md).
///
/// sourcery: CreateMock
@MainActor
public protocol DiagnosticsLogging {
  func log(level: LogLevel, _ message: String)
  func exception(_ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String)
}

/// The observable half: the in-process log stream (debug overlays, test
/// assertions). Kotlin twin: a `Flow` of the same pairs.
///
/// sourcery: CreateMock
@MainActor
public protocol DiagnosticsLogsObserving: DiagnosticsLogging {
  var logs: AnyPublisher<(level: LogLevel, message: String), Never> { get }
}

/// The full surface the composition root sees: logging + the crash-reporter
/// user-context setters (forwarded to the injected hooks; no backend ⇒ no-op).
///
/// sourcery: CreateMock
@MainActor
public protocol Diagnostics: DiagnosticsLogsObserving {
  func setUserID(_ userID: String?)
  func setCustomValue(_ value: Any?, forKey key: String)
}

public extension DiagnosticsLogging {
  func info(_ message: String) { log(level: .info, message) }
  func warn(_ message: String) { log(level: .warn, message) }
  func error(_ message: String) { log(level: .error, message) }
  func fatal(_ message: String) { log(level: .fatal, message) }

  func exception(
    _ error: Error,
    userInfo: [String: Any]? = nil,
    file: String = #file,
    line: Int = #line,
    function: String = #function) {
      exception(error, userInfo: userInfo, file: file, line: line, function: function)
    }
}
