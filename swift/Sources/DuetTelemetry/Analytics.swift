// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// The grammar-typed analytics port — the ONE sink interface. Features and
/// workers depend on this, never on a vendor SDK: when the app picks a
/// vendor (Amplitude, PostHog, …), it adds ONE new file conforming to this
/// protocol, and that file is the ONLY file that imports the SDK. Sinks
/// render events through `encodedName()` and `encodedProperties()` — the
/// grammar owns the taxonomy; sinks own transport. Until a vendor lands the
/// composition root wires `NoOpAnalytics` — a working default, not a stub.
public protocol AnalyticsTracking: AnyObject {
  /// Emit a typed event. A no-op when opted out or when no vendor is wired.
  func track(event: TrackedEvent)

  /// Associate subsequent events with the signed-in user (a pseudonymous
  /// identifier — never an email or a display name). Call on sign-in.
  func identify(uid: String)

  /// Clear the user association. Call on sign-out.
  func reset()

  /// Flip the opt-out gate — keep in step with the app's consent store (the
  /// composition root observes the store and forwards changes here).
  func setOptedOut(_ optedOut: Bool)
}

/// The working default: accepted and dropped (the zero-sink degenerate of
/// `CompositeAnalytics`).
public final class NoOpAnalytics: AnalyticsTracking {
  public init() {}
  public func track(event: TrackedEvent) {}
  public func identify(uid: String) {}
  public func reset() {}
  public func setOptedOut(_ optedOut: Bool) {}
}

/// The sink fan-out, SDK-free: every call fans to each sink, so adding or
/// removing a vendor is a one-line change at the composition root. The
/// opt-out gate lives HERE, once — sinks never see events while opted out
/// (identify/reset pass through so the gate cannot strand a stale user
/// association). Consent gates the SINK, never the emission: reducers emit
/// unconditionally, so the fixture contract stays deterministic and opt-out
/// is a drop at this gate.
public final class CompositeAnalytics: AnalyticsTracking {

  private let sinks: [any AnalyticsTracking]
  private let lock = NSLock()
  private var optedOut: Bool

  public init(sinks: [any AnalyticsTracking], initiallyOptedOut: Bool = false) {
    self.sinks = sinks
    self.optedOut = initiallyOptedOut
    // The persisted seed reaches vendor SDKs immediately — a sink must never
    // egress in the window between construction and the first flip.
    sinks.forEach { $0.setOptedOut(initiallyOptedOut) }
  }

  public func track(event: TrackedEvent) {
    lock.lock()
    let gated = optedOut
    lock.unlock()
    guard !gated else { return }
    sinks.forEach { $0.track(event: event) }
  }

  public func identify(uid: String) {
    sinks.forEach { $0.identify(uid: uid) }
  }

  public func reset() {
    sinks.forEach { $0.reset() }
  }

  public func setOptedOut(_ optedOut: Bool) {
    lock.lock()
    self.optedOut = optedOut
    lock.unlock()
    // Forwarded so vendor SDKs also stop their own background egress.
    sinks.forEach { $0.setOptedOut(optedOut) }
  }
}
