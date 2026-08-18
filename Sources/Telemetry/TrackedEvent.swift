// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The event GRAMMAR — a vocabulary, not a catalog. Every analytics event in
/// the app is one `TrackedEvent`: a subject, a verb from the app's verb
/// vocabulary, and an ordered list of primitive params. Nodes declare their
/// own named events from this grammar (one builder per event, in a
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

/// A verb — one token from the app's verb vocabulary.
///
/// The vocabulary is the APP's, not this package's: the verbs below are the
/// ones most apps start from, and an app adds its own in one line, wherever
/// it needs them:
///
/// ```swift
/// public extension TrackedVerb {
///   static let shared = TrackedVerb("Shared")
///   static let regenerated = TrackedVerb("Regenerated")
/// }
/// ```
///
/// A struct rather than an enum, and that is the whole reason: an enum's
/// cases are fixed by the module that declares them, so a linked grammar
/// would cap every app's taxonomy at this file's list — and a kmp-flavored
/// app, whose reducers mint verbs in Kotlin, could not carry a Kotlin verb
/// across the language boundary without an edit here. What the app gives up
/// is the compiler's exhaustiveness check over verbs, which nothing in the
/// grammar switched on.
///
/// Adding a verb stays a taxonomy decision — a new vendor-facing name family
/// every dashboard then keys on — reviewed like one, not a call-site
/// convenience. Reach for an existing verb first.
///
/// `rawValue` is the token, and the token is the whole story: the identity
/// (`==` and hashing), the wire form (a verb encodes as the bare string),
/// and the vendor-facing spelling (`encodedName()` splices it after the
/// subject). Mint it spelled exactly as a dashboard should read it —
/// `TrackedVerb("Signed Out")`. A dual-language app's converter picks the
/// token for a crossing verb from the Kotlin declaration's display name, so
/// both languages spell one event one way because ONE declaration is the
/// source — there is no derivation to keep in step.
public struct TrackedVerb: RawRepresentable, Hashable, Codable, Sendable {

  /// The token — Title Case, spelled as displayed (`"Signed Out"`).
  public let rawValue: String

  public init(rawValue: String) {
    assert(!rawValue.isEmpty, "a verb token must not be empty")
    self.rawValue = rawValue
  }

  /// The spelling a call site reads best: `TrackedVerb("Shared")`.
  public init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  // The starter vocabulary — the verbs an app is likeliest to need on day
  // one. Not a closed set and not scaffold-content: an app adds to it with
  // an extension (above) and simply does not name the ones it has no use
  // for.
  public static let viewed = TrackedVerb("Viewed")
  public static let opened = TrackedVerb("Opened")
  public static let started = TrackedVerb("Started")
  public static let completed = TrackedVerb("Completed")
  public static let failed = TrackedVerb("Failed")
  public static let created = TrackedVerb("Created")
  public static let edited = TrackedVerb("Edited")
  public static let deleted = TrackedVerb("Deleted")
  public static let toggled = TrackedVerb("Toggled")
  public static let signedOut = TrackedVerb("Signed Out")

  // The wire form is the token alone — a bare string. Swift's
  // `RawRepresentable` default coding also encodes the bare string; the
  // explicit pair pins that wire form as this type's contract instead of
  // inheriting it.
  public init(from decoder: Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
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
  /// `"Subject Verb"`, Title Case, the verb token verbatim. Pinned by a
  /// logical test (fixtures record grammar VALUES; the name is derived).
  public func encodedName() -> String { "\(subject) \(verb.rawValue)" }

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
