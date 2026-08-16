// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The event GRAMMAR — a closed vocabulary, not a catalog. Every analytics
/// event in the app is one `TrackedEvent`: a subject, a verb from the closed
/// set, and an ordered list of primitive params. Nodes declare their own
/// named events from this grammar (one builder per event, in a
/// `<Node>Events` enum next to the feature) and reducers emit them as
/// `.track` effects, so which event fires on which transition — params
/// included — is fixture-gated.
///
/// Params are primitives only (string/int/bool/double). That constraint is
/// also the privacy rule: values are behavioral metadata — counts, flags,
/// enum names, durations — NEVER user content, names, emails, or free text.
/// A list or date enters as a string through an encoding stated at the call
/// site (e.g. sorted comma-join, ISO-8601).
public struct TrackedEvent: Equatable, Codable, Sendable {
  public let subject: String
  public let verb: TrackedVerb
  public let params: [TrackedParam]

  public init(subject: String, verb: TrackedVerb, params: [TrackedParam] = []) {
    self.subject = subject
    self.verb = verb
    self.params = params
  }
}

/// The closed verb set. Growing it is a taxonomy decision (a new
/// vendor-facing name family), reviewed like one — not a call-site
/// convenience. `rendered` is the vendor-facing spelling; the serialized
/// form stays the case's raw value.
public enum TrackedVerb: String, Equatable, Codable, Sendable {
  // scaffold-content: the starter verb set — grow or trim to YOUR app's
  // taxonomy; keep the set closed.
  case viewed = "Viewed"
  case opened = "Opened"
  case started = "Started"
  case completed = "Completed"
  case failed = "Failed"
  case created = "Created"
  case edited = "Edited"
  case deleted = "Deleted"
  case toggled = "Toggled"
  case signedOut = "SignedOut"
  // /scaffold-content

  /// The vendor-facing spelling.
  public var rendered: String {
    switch self {
    case .signedOut: return "Signed Out"
    default: return rawValue
    }
  }
}

/// One typed param. Keys are snake_case literals, stated at the builder.
/// Four cases, ONE hand-written case-envelope coder (below), forever — a new
/// EVENT never touches serialization. (The coder is hand-written because
/// this package is not a manifest feature, so the toolchain's generated-sum
/// pipeline never scans it; the wire form is pinned by a logical test.)
public enum TrackedParam: Equatable, Sendable {
  case string(key: String, value: String)
  case int(key: String, value: Int)
  case bool(key: String, value: Bool)
  case double(key: String, value: Double)

  public var key: String {
    switch self {
    case let .string(key, _): return key
    case let .int(key, _): return key
    case let .bool(key, _): return key
    case let .double(key, _): return key
    }
  }
}

// MARK: - The canonical case envelope, by hand

extension TrackedParam: Codable {
  private enum EnvelopeKey: String, CodingKey {
    case caseName = "case"
    case value
  }

  private enum PayloadKey: String, CodingKey {
    case key
    case value
  }

  public func encode(to encoder: Encoder) throws {
    var envelope = encoder.container(keyedBy: EnvelopeKey.self)
    var payload = envelope.nestedContainer(keyedBy: PayloadKey.self, forKey: .value)
    switch self {
    case let .string(key, value):
      try envelope.encode("string", forKey: .caseName)
      try payload.encode(key, forKey: .key)
      try payload.encode(value, forKey: .value)
    case let .int(key, value):
      try envelope.encode("int", forKey: .caseName)
      try payload.encode(key, forKey: .key)
      try payload.encode(value, forKey: .value)
    case let .bool(key, value):
      try envelope.encode("bool", forKey: .caseName)
      try payload.encode(key, forKey: .key)
      try payload.encode(value, forKey: .value)
    case let .double(key, value):
      try envelope.encode("double", forKey: .caseName)
      try payload.encode(key, forKey: .key)
      try payload.encode(value, forKey: .value)
    }
  }

  public init(from decoder: Decoder) throws {
    let envelope = try decoder.container(keyedBy: EnvelopeKey.self)
    let caseName = try envelope.decode(String.self, forKey: .caseName)
    let payload = try envelope.nestedContainer(keyedBy: PayloadKey.self, forKey: .value)
    let key = try payload.decode(String.self, forKey: .key)
    switch caseName {
    case "string":
      self = .string(key: key, value: try payload.decode(String.self, forKey: .value))
    case "int":
      self = .int(key: key, value: try payload.decode(Int.self, forKey: .value))
    case "bool":
      self = .bool(key: key, value: try payload.decode(Bool.self, forKey: .value))
    case "double":
      self = .double(key: key, value: try payload.decode(Double.self, forKey: .value))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .caseName, in: envelope, debugDescription: "Unknown TrackedParam case '\(caseName)'")
    }
  }
}

// MARK: - The derived vendor surface

extension TrackedEvent {
  /// The vendor-facing event name — ONE encoding rule for every sink:
  /// `"Subject Verb"`, Title Case. Pinned by a logical test (fixtures record
  /// grammar VALUES; the name is derived).
  public func encodedName() -> String { "\(subject) \(verb.rendered)" }

  /// The vendor-facing property bag — the ordered param list flattened to
  /// key/value pairs. Sinks hand this to their SDK verbatim.
  public func encodedProperties() -> [String: Any] {
    var bag: [String: Any] = [:]
    for param in params {
      switch param {
      case let .string(key, value): bag[key] = value
      case let .int(key, value): bag[key] = value
      case let .bool(key, value): bag[key] = value
      case let .double(key, value): bag[key] = value
      }
    }
    return bag
  }
}
