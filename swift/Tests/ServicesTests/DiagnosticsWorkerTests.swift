// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import DuetDiagnostics
import DuetTesting
import Foundation
import XCTest

/// The diagnostics worker's logical receipts through the framework bracket
/// (WorkerTester): behavioral assertions only — services are never
/// parity-gated.
/// Test-local accumulator that crosses the hooks' `@Sendable` boundary
/// cleanly under complete concurrency checking. `@unchecked Sendable` is
/// acceptable in TEST sources only — a lock guards every access; in
/// production code the worker-isolation rule applies instead.
private final class Recorded<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Value] = []

  func append(_ value: Value) {
    lock.lock()
    storage.append(value)
    lock.unlock()
  }

  var values: [Value] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}

final class DiagnosticsWorkerTests: XCTestCase {

  @MainActor
  func testLogsReachTheStreamAndTheHooks() async {
    let worker = DiagnosticsWorker()
    let hookLines = Recorded<String>()
    worker.setHooks(DiagnosticsHooks(log: { hookLines.append($0) }))

    var streamed: [(level: LogLevel, message: String)] = []
    let cancellable = worker.logs.sink { streamed.append($0) }
    defer { cancellable.cancel() }

    let tester = WorkerTester(worker)
    tester.start()

    worker.info("hello")
    worker.error("broke")

    XCTAssertEqual(streamed.map(\.level), [.info, .error])
    XCTAssertEqual(streamed.map(\.message), ["hello", "broke"])
    XCTAssertEqual(hookLines.values, ["ℹ️: hello", "❗️: broke"])

    await tester.finish()
  }

  @MainActor
  func testExceptionForwardsToTheRecordHookWithCallSiteInfo() async {
    let worker = DiagnosticsWorker()
    let recorded = Recorded<(Error, [String: Any]?)>()
    worker.setHooks(DiagnosticsHooks(record: { recorded.append(($0, $1)) }))

    let tester = WorkerTester(worker)
    tester.start()

    struct SampleError: Error {}
    worker.exception(SampleError(), userInfo: ["key": "value"])

    XCTAssertEqual(recorded.values.count, 1)
    let info = recorded.values[0].1
    XCTAssertEqual(info?["key"] as? String, "value")
    XCTAssertNotNil(info?["_file_"])

    await tester.finish()
  }

  @MainActor
  func testUserContextSettersAreNoOpsWithoutHooks() async {
    let worker = DiagnosticsWorker()
    let tester = WorkerTester(worker)
    tester.start()

    // No hooks set — must not trap or emit.
    worker.setUserID("uid")
    worker.setCustomValue(1, forKey: "k")

    await tester.finish()
  }
}
