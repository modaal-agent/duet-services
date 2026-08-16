// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import AppServices
import DuetTesting
import Foundation
import XCTest

/// The inbound registry's logical receipts: priority-ordered first-match
/// dispatch, registration handles that unregister on cancel, and the
/// no-leak bracket guarantee.
final class AppServicesWorkerTests: XCTestCase {

  @MainActor
  func testDispatchPrefersHigherPriorityFirstMatch() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let fallback = FakeURLHandler()
    let high = FakeURLHandler()
    let fallbackToken = worker.registerURLHandler(fallback, priority: .fallback)
    let highToken = worker.registerURLHandler(high, priority: .high)
    defer {
      fallbackToken.cancel()
      highToken.cancel()
    }

    let url = URL(string: "https://example.com/a")!
    worker.openURL(url)

    XCTAssertEqual(high.handled, [url])
    XCTAssertEqual(fallback.handled, [])

    await tester.finish()
  }

  @MainActor
  func testUnclaimedURLsFallThroughToTheNextHandler() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let picky = FakeURLHandler(canHandle: { $0.scheme == "app" })
    let catchAll = FakeURLHandler()
    let pickyToken = worker.registerURLHandler(picky, priority: .high)
    let catchAllToken = worker.registerURLHandler(catchAll, priority: .fallback)
    defer {
      pickyToken.cancel()
      catchAllToken.cancel()
    }

    let web = URL(string: "https://example.com")!
    let deep = URL(string: "app://open")!
    worker.openURLs([web, deep])

    XCTAssertEqual(picky.handled, [deep])
    XCTAssertEqual(catchAll.handled, [web])

    await tester.finish()
  }

  @MainActor
  func testCancellingTheTokenUnregisters() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let handler = FakeURLHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    token.cancel()

    worker.openURL(URL(string: "https://example.com")!)
    XCTAssertEqual(handler.handled, [])

    await tester.finish()
  }
}
