// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Dispatch priority for inbound handler registrations on
/// `InboundAppServicesWorker`. Higher rawValue wins — the worker sorts handlers
/// descending by `rawValue` and calls the first one whose `canHandle*`
/// returns `true`.
public enum AppServicePriority: Int, Sendable {
  case high = 1000
  case `default` = 100
  case fallback = 0
}
