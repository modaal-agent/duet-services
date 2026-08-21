// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import DuetTelemetry
import XCTest

/// The twin contract's Swift half — serialized equivalence at the substrate
/// tier. The Kotlin half of this package DECLARES the sample events and
/// writes the fixtures under `contracts/telemetry-twin/` through its own
/// encoders (so the Kotlin declaration's stored display name is the one
/// spelling source); this test decodes each fixture with this module's
/// coding and asserts the derived surfaces agree — a verb spelling declared
/// once must survive both languages' encoders.
///
/// Three assertions per fixture:
///   1. `encodedName()` over the decoded event equals the fixture's
///      `encodedName` — the vendor-facing spelling crossed losslessly.
///   2. `encodedProperties()` equals the fixture's `encodedProperties` bag,
///      value for typed value.
///   3. Re-encoding the decoded event yields the fixture's `event` JSON —
///      the two encoders produce one wire form.
final class TwinContractTests: XCTestCase {

  /// The committed fixture set, closed both ways: a file this list misses
  /// and a listed name with no file both fail.
  private static let fixtureNames = [
    "app-minted-verb",
    "empty-params",
    "envelope",
    "multiword-verb",
    "param-cases",
  ]

  /// `swift/Tests/TelemetryTests/` → the repo root → `contracts/telemetry-twin`.
  private var fixturesDirectory: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("contracts/telemetry-twin", isDirectory: true)
  }

  func testTheCommittedFixtureSetIsClosed() throws {
    let onDisk = try FileManager.default
      .contentsOfDirectory(atPath: fixturesDirectory.path)
      .filter { $0.hasSuffix(".fixture.json") }
      .map { String($0.dropLast(".fixture.json".count)) }
      .sorted()
    XCTAssertEqual(onDisk, Self.fixtureNames)
  }

  func testEveryFixtureCrossesLosslessly() throws {
    for name in Self.fixtureNames {
      let url = fixturesDirectory.appendingPathComponent("\(name).fixture.json")
      let data = try Data(contentsOf: url)
      let document = try XCTUnwrap(
        try JSONSerialization.jsonObject(with: data) as? [String: Any], name)
      let eventJSON = try XCTUnwrap(document["event"], name)
      let expectedName = try XCTUnwrap(document["encodedName"] as? String, name)
      let expectedBag = try XCTUnwrap(document["encodedProperties"] as? [String: Any], name)

      // The Kotlin-serialized event decodes through this module's coding.
      let eventData = try JSONSerialization.data(withJSONObject: eventJSON)
      let event = try JSONDecoder().decode(TrackedEvent.self, from: eventData)

      // 1. The vendor-facing spelling.
      XCTAssertEqual(event.encodedName(), expectedName, name)

      // 2. The property bag, typed value for typed value. NSDictionary
      // equality compares NSNumber values numerically, which is exactly the
      // bag contract (2 is 2, 1.5 is 1.5, true is true).
      XCTAssertEqual(
        event.encodedProperties() as NSDictionary, expectedBag as NSDictionary, name)

      // 3. One wire form: this module's encoder emits the structure the
      // Kotlin encoder wrote. Both sides re-serialize with sorted keys so
      // the comparison is over canonical bytes.
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let reencoded = try encoder.encode(event)
      let fixtureCanonical = try JSONSerialization.data(
        withJSONObject: eventJSON, options: [.sortedKeys])
      let reencodedCanonical = try JSONSerialization.data(
        withJSONObject: JSONSerialization.jsonObject(with: reencoded), options: [.sortedKeys])
      XCTAssertEqual(
        String(decoding: reencodedCanonical, as: UTF8.self),
        String(decoding: fixtureCanonical, as: UTF8.self),
        name)
    }
  }
}
