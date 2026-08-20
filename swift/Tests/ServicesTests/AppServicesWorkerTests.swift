// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import DuetAppServices
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

    let fallback = makeHandler()
    let high = makeHandler()
    let fallbackToken = worker.registerURLHandler(fallback, priority: .fallback)
    let highToken = worker.registerURLHandler(high, priority: .high)
    defer {
      fallbackToken.cancel()
      highToken.cancel()
    }
    worker.handlersDidRegister()

    let url = URL(string: "https://example.com/a")!
    worker.openURL(url)

    XCTAssertEqual(high.handleOpenUrlArgs, [url])
    XCTAssertEqual(fallback.handleOpenUrlArgs, [])

    await tester.finish()
  }

  @MainActor
  func testUnclaimedURLsFallThroughToTheNextHandler() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let picky = makeHandler(canHandle: { $0.scheme == "app" })
    let catchAll = makeHandler()
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

    XCTAssertEqual(picky.handleOpenUrlArgs, [deep])
    XCTAssertEqual(catchAll.handleOpenUrlArgs, [web])

    await tester.finish()
  }

  @MainActor
  func testCancellingTheTokenUnregisters() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let handler = makeHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    worker.handlersDidRegister()
    token.cancel()

    worker.openURL(URL(string: "https://example.com")!)
    XCTAssertEqual(handler.handleOpenUrlArgs, [])

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

    let catchAll = makeHandler()
    let catchAllToken = worker.registerURLHandler(catchAll, priority: .fallback)

    let launchURL = URL(string: "https://example.com/files/abc")!
    worker.openURL(launchURL)
    XCTAssertEqual(catchAll.handleOpenUrlArgs, [], "a pre-settle event must not dispatch")

    let claimant = makeHandler(canHandle: { $0.path.hasPrefix("/files") })
    let claimantToken = worker.registerURLHandler(claimant, priority: .high)
    defer {
      catchAllToken.cancel()
      claimantToken.cancel()
    }

    worker.handlersDidRegister()

    XCTAssertEqual(claimant.handleOpenUrlArgs, [launchURL])
    XCTAssertEqual(catchAll.handleOpenUrlArgs, [])

    await tester.finish()
  }

  /// Buffered events keep arrival order, and the signal is one-way: a second
  /// call delivers nothing a second time.
  @MainActor
  func testTheDrainKeepsArrivalOrderAndHappensOnce() async {
    let worker = AppServicesWorker()
    let tester = WorkerTester(worker)
    tester.start()

    let handler = makeHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    defer { token.cancel() }

    let first = URL(string: "app://one")!
    let second = URL(string: "app://two")!
    worker.openURL(first)
    worker.openURL(second)

    worker.handlersDidRegister()
    XCTAssertEqual(handler.handleOpenUrlArgs, [first, second])

    worker.handlersDidRegister()
    XCTAssertEqual(handler.handleOpenUrlArgs, [first, second])

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

    let handler = makeHandler()
    let token = worker.registerURLHandler(handler, priority: .default)
    defer { token.cancel() }
    worker.handlersDidRegister()

    XCTAssertEqual(handler.handleOpenUrlArgs, Array(urls.prefix(8)))

    await tester.finish()
  }
}


/// The generated recording mock, seeded as a claimant: the bare mock's
/// `canHandleOpenUrl` answers `false`, and every registration in these tests
/// wants a live claim answer.
private func makeHandler(
  canHandle: @escaping (URL) -> Bool = { _ in true }
) -> URLHandlingMock {
  let mock = URLHandlingMock()
  mock.canHandleOpenUrlHandler = canHandle
  return mock
}
