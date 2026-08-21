// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import DuetShells

/// The grammar-typed analytics port — the ONE sink interface. Features and
/// workers depend on this, never on a vendor SDK: when the app picks a vendor
/// (Amplitude, PostHog, …), it adds ONE new file conforming to
/// `AnalyticsTrackingWorking`, and that file is the ONLY file that imports the
/// SDK. Sinks render events through `encodedName()` and `encodedProperties()`
/// — the grammar owns the taxonomy; sinks own transport.
///
/// Consent is the app's to hold. This port carries the flag and nothing else:
/// where the user's choice is persisted, which screen changes it, and whether
/// an analytics worker is constructed at all are decisions the app makes in
/// its own tree.
///
/// sourcery: CreateMock
public protocol AnalyticsTracking: AnyObject {
  /// `true` while at least one sink is permitted to egress. This answers "is
  /// anything being sent right now", not "what did the user choose" — bind a
  /// Settings toggle to the app's own consent storage, not to this.
  var isEnabled: Bool { get }

  /// Permit or stop egress, at every sink. The read and the write are
  /// separate members because they answer different questions: this pushes a
  /// value down, `isEnabled` folds back what the sinks report, and with no
  /// sink wired the two do not agree.
  func setEnabled(_ enabled: Bool)

  /// Emit a typed event. A no-op while egress is stopped and while no sink is
  /// wired.
  func track(event: TrackedEvent)

  /// Associate subsequent events with the signed-in user (a pseudonymous
  /// identifier — never an email or a display name). Call on sign-in.
  func identify(uid: String)

  /// Clear the user association. Call on sign-out.
  func reset()
}

/// The port a vendor sink conforms to. A sink is a worker: the composition
/// root adopts it, and its egress runs inside the mount's lifetime.
///
/// A `Working` is `Sendable`, so a sink cannot hold the enabled flag as a
/// plain `var`. Delegate to the vendor SDK's own opt-out switch — which is
/// where the flag has to reach anyway, so the SDK stops its own background
/// egress — and read it back in `isEnabled`. Where an SDK exposes no readable
/// switch, hold the flag in an `OSAllocatedUnfairLock<Bool>` and mirror it to
/// the SDK.
///
/// sourcery: CreateMock
public protocol AnalyticsTrackingWorking: AnalyticsTracking, Working {}

/// The sink fan-out, SDK-free: every call reaches every sink, so adding or
/// removing a vendor is a one-line change at the composition root. It stores
/// `let sinks` and nothing else — no gate, no lock, no unchecked conformance.
/// Each sink decides for itself whether an event leaves the device, which is
/// where the vendor SDK's own switch already lives.
///
/// `AnalyticsTrackingWorker(sinks: [])` is the working default before a vendor
/// is picked: every call is accepted and dropped, and `isEnabled` reads
/// `false`.
public final class AnalyticsTrackingWorker: AnalyticsTrackingWorking {

  private let sinks: [any AnalyticsTrackingWorking]

  /// - Parameters:
  ///   - sinks: the vendor sinks to fan out to. Each is adopted by the
  ///     composition root in its own right — this worker does not bracket
  ///     their lifetimes.
  ///   - isEnabled: pushed into every sink before this initializer returns, so
  ///     no sink egresses in the window between composition and the first
  ///     flip. Pass the app's persisted choice.
  public init(sinks: [any AnalyticsTrackingWorking], isEnabled: Bool = true) {
    self.sinks = sinks
    sinks.forEach { $0.setEnabled(isEnabled) }
  }

  /// `true` when ANY sink reports itself enabled. Sinks disagree only when a
  /// caller sets one directly instead of through this worker, and for a
  /// consent readback over-reporting egress is the safe direction.
  public var isEnabled: Bool { sinks.contains { $0.isEnabled } }

  public func setEnabled(_ enabled: Bool) {
    sinks.forEach { $0.setEnabled(enabled) }
  }

  public func track(event: TrackedEvent) {
    sinks.forEach { $0.track(event: event) }
  }

  public func identify(uid: String) {
    sinks.forEach { $0.identify(uid: uid) }
  }

  public func reset() {
    sinks.forEach { $0.reset() }
  }

  /// Parks until the host cancels. The sinks run their own `run()`.
  public func run() async {
    await untilCancelled()
  }
}
