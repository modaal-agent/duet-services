// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Combine
import Foundation

/// Single source of truth for whether the user permits product-analytics
/// egress. Backed by `UserDefaults` so it survives launches and stays in
/// step, by key, across every store instance in the process — the
/// composition root's instance and a Settings screen's instance never need
/// a shared reference.
///
/// Default is **on**: analytics ship unless the user opts out. Default-on is
/// only compliant when a visible Settings disclosure names the vendor — ship
/// that row with the vendor, not later.
///
/// sourcery: CreateMock
public protocol AnalyticsConsentStoring: AnyObject {
  /// `true` when the user permits analytics egress (the default).
  var isEnabled: Bool { get set }
  /// Emits the current value on subscribe and on every subsequent change
  /// (including changes made by a different store instance in the process).
  /// The seeded-subject annotation makes the generated mock's backing
  /// subject a `CurrentValueSubject`, so a double reproduces the
  /// emit-on-subscribe half of this contract without per-test wiring.
  /// sourcery: subject = "CurrentValue"
  var isEnabledPublisher: AnyPublisher<Bool, Never> { get }
}

public final class UserDefaultsAnalyticsConsentStore: AnalyticsConsentStoring {

  // Namespaced so it can't collide with feature flags. Absent key ⇒ enabled.
  static let defaultsKey = "analytics.sharing_enabled"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var isEnabled: Bool {
    get {
      // Absent ⇒ default-on. `object(forKey:)` distinguishes "never set"
      // from an explicit `false`.
      guard defaults.object(forKey: Self.defaultsKey) != nil else { return true }
      return defaults.bool(forKey: Self.defaultsKey)
    }
    set { defaults.set(newValue, forKey: Self.defaultsKey) }
  }

  public var isEnabledPublisher: AnyPublisher<Bool, Never> {
    NotificationCenter.default
      .publisher(for: UserDefaults.didChangeNotification, object: defaults)
      .map { [weak self] _ in self?.isEnabled ?? true }
      .prepend(isEnabled)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
}
