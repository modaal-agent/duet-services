// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import DuetTelemetry
import Combine
import Foundation
import XCTest

/// Consent-store receipts: default-on with an absent key, persistence by
/// key, and the subscribe-time emission.
final class AnalyticsConsentStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private let suiteName = "telemetry-tests.analytics-consent"

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    super.tearDown()
  }

  func testConsentDefaultsToEnabled() {
    let store = UserDefaultsAnalyticsConsentStore(defaults: defaults)
    XCTAssertTrue(store.isEnabled)
  }

  func testOptOutPersistsAcrossInstances() {
    let store = UserDefaultsAnalyticsConsentStore(defaults: defaults)
    store.isEnabled = false

    let second = UserDefaultsAnalyticsConsentStore(defaults: defaults)
    XCTAssertFalse(second.isEnabled)
  }

  func testPublisherEmitsCurrentValueOnSubscribe() {
    let store = UserDefaultsAnalyticsConsentStore(defaults: defaults)
    var values: [Bool] = []
    let cancellable = store.isEnabledPublisher.sink { values.append($0) }
    defer { cancellable.cancel() }

    XCTAssertEqual(values, [true])
  }
}
