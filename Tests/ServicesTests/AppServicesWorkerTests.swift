// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import AppServices
import DuetTesting
import Foundation
import XCTest

/// The inbound registry's logical receipts: priority-ordered first-match
/// dispatch, registration handles that unregister on cancel, the launch
/// buffer that holds events until the registration burst completes, and the
/// no-leak bracket guarantee.
///
/// Every dispatch test calls `handlersDidRegister()` first, because that is
/// what an app does: the ingress worker registers its handlers and then
/// signals the burst complete. Before the signal, inbound events buffer.
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
    worker.handlersDidRegister()

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
    worker.handlersDidRegister()

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
    worker.handlersDidRegister()
    token.cancel()

    worker.openURL(URL(string: "https://example.com")!)
    XCTAssertEqual(handler.handled, [])

    await tester.finish()
  }

  /// The launch window: an event that arrives while the registry is still
  /// filling is held, then dispatched against the COMPLETE registry. The
  /// high-priority handler here registers AFTER the URL arrives — a
  /// per-registration drain would have handed it to the catch-all.
  @MainActor
  func testEventsBeforeTheSettleSignalDrainAgainstTheFullRegistry() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let catchAll = FakeURLHandler()
    let catchAllToken = worker.registerURLHandler(catchAll, priority: .fallback)

    let launchURL = URL(string: "https://example.com/files/abc")!
    worker.openURL(launchURL)
    XCTAssertEqual(catchAll.handled, [], "a pre-settle event must not dispatch")

    let claimant = FakeURLHandler(canHandle: { $0.path.hasPrefix("/files") })
    let claimantToken = worker.registerURLHandler(claimant, priority: .high)
    defer {
      catchAllToken.cancel()
      claimantToken.cancel()
    }

    worker.handlersDidRegister()

    XCTAssertEqual(claimant.handled, [launchURL])
    XCTAssertEqual(catchAll.handled, [])

    await tester.finish()
  }

  /// Buffered events keep arrival order, and the signal is one-way: a second
  /// call delivers nothing a second time.
  @MainActor
  func testTheDrainKeepsArrivalOrderAndHappensOnce() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let handler = FakeURLHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    defer { token.cancel() }

    let first = URL(string: "app://one")!
    let second = URL(string: "app://two")!
    worker.openURL(first)
    worker.openURL(second)

    worker.handlersDidRegister()
    XCTAssertEqual(handler.handled, [first, second])

    worker.handlersDidRegister()
    XCTAssertEqual(handler.handled, [first, second])

    await tester.finish()
  }

  /// The buffer is a backstop with a cap: if the registrar never runs, the
  /// worker drops the overflow rather than growing without bound.
  @MainActor
  func testTheLaunchBufferIsCapped() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let urls = (0..<12).map { URL(string: "app://\($0)")! }
    urls.forEach { worker.openURL($0) }

    let handler = FakeURLHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    defer { token.cancel() }
    worker.handlersDidRegister()

    XCTAssertEqual(handler.handled, Array(urls.prefix(8)))

    await tester.finish()
  }
}
