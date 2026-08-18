// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import Telemetry
import XCTest

/// A verb this package does not declare, added the way an app adds one.
private extension TrackedVerb {
  static let archived = TrackedVerb("Archived")
}

/// The logical pins for the grammar's DERIVED surface: fixtures record
/// grammar VALUES; the vendor-facing name and property bag are derived, so
/// the encoding rule is pinned here — exact strings — instead of by
/// fixtures. The wire-form pin covers the hand-written param envelope (this
/// package is outside the toolchain's generated-sum pipeline).
final class TrackedEventTests: XCTestCase {

  func testEncodedNameIsSubjectSpaceVerb() {
    XCTAssertEqual(TrackedEvent(subject: "Item", verb: .created).encodedName(), "Item Created")
    XCTAssertEqual(
      TrackedEvent(subject: "Item Load", verb: .failed).encodedName(), "Item Load Failed")
    // A multi-word token splices verbatim.
    XCTAssertEqual(
      TrackedEvent(subject: "Session", verb: .signedOut).encodedName(), "Session Signed Out")
  }

  /// The extension point: a verb this package never declared behaves like
  /// one it did — encoded, decoded and compared the same way.
  func testAnAppDeclaredVerbIsAFirstClassVerb() throws {
    let event = TrackedEvent(subject: "Report", verb: .archived)

    XCTAssertEqual(event.encodedName(), "Report Archived")

    let encoded = try JSONEncoder().encode(event)
    XCTAssertEqual(try JSONDecoder().decode(TrackedEvent.self, from: encoded), event)
  }

  /// The wire form is the bare token, and the token survives a decode
  /// unchanged — it is also the vendor-facing spelling, so there is no
  /// second storage to drift.
  func testTheTokenIsTheWireFormAndSurvivesADecode() throws {
    let encoded = try JSONEncoder().encode(TrackedVerb.signedOut)
    XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #""Signed Out""#)
    XCTAssertEqual(try JSONDecoder().decode(TrackedVerb.self, from: encoded), .signedOut)
  }

  /// Identity is the token: two spellings of one verb are one verb, whichever
  /// initializer minted them.
  func testVerbIdentityIsTheToken() {
    XCTAssertEqual(TrackedVerb("Completed"), .completed)
    XCTAssertEqual(TrackedVerb(rawValue: "Completed"), .completed)
    XCTAssertEqual(Set([TrackedVerb("Completed"), .completed]).count, 1)
    XCTAssertNotEqual(TrackedVerb("Completed"), .created)
  }

  func testEncodedPropertiesFlattenTheParamList() {
    let event = TrackedEvent(
      subject: "Item",
      verb: .created,
      params: [
        .bool(key: "has_description", value: true),
        .int(key: "photo_count", value: 2),
        .string(key: "from", value: "capture"),
        .double(key: "duration_s", value: 1.5),
      ])
    let bag = event.encodedProperties()
    XCTAssertEqual(bag.count, 4)
    XCTAssertEqual(bag["has_description"] as? Bool, true)
    XCTAssertEqual(bag["photo_count"] as? Int, 2)
    XCTAssertEqual(bag["from"] as? String, "capture")
    XCTAssertEqual(bag["duration_s"] as? Double, 1.5)
  }

  func testWireFormIsTheCanonicalCaseEnvelope() throws {
    // The exact bytes feature fixtures embed for a `.track` effect's event —
    // a contract, pinned: subject/verb/params product, params as case sums.
    let event = TrackedEvent(
      subject: "Item Load",
      verb: .failed,
      params: [
        .string(key: "reason", value: "offline"),
        .bool(key: "retried", value: false),
      ])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = String(decoding: try encoder.encode(event), as: UTF8.self)
    XCTAssertEqual(
      json,
      #"{"params":[{"case":"string","value":{"key":"reason","value":"offline"}},"#
        + #"{"case":"bool","value":{"key":"retried","value":false}}],"#
        + #""subject":"Item Load","verb":"Failed"}"#)
    let decoded = try JSONDecoder().decode(TrackedEvent.self, from: Data(json.utf8))
    XCTAssertEqual(decoded, event)
  }
}
