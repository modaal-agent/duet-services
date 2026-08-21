// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import DuetShells
import Foundation

/// The composed inbound contract: everything a composition root needs from the
/// inbound worker in one type — adopt it as a `Working`, hand it the delegate
/// callbacks it dispatches (`AppServiceHandling`), let features register as
/// handlers (`AppServicesRegistering`), and let them subscribe to lifecycle
/// transitions (`AppLifecycleObserving`).
///
/// A feature depends on one of the narrow protocols instead: a feature that
/// receives deep links takes `AppServicesRegistering`, a feature that pauses
/// on backgrounding takes `AppLifecycleObserving`. The composite exists so the
/// composition root has one type to store.
///
/// The two composed halves each drop their UIKit members on a lane without
/// UIKit, so this declaration is the same on every lane and the worker behind
/// it implements whichever set compiles.
///
/// NOT CreateMock-annotated: it composes platform-conditional protocols, and a
/// generated mock is unconditional — the macOS host lane cannot compile the
/// UIKit branch's members. Depend on the narrow ports, each of which has its
/// own generated double.
@MainActor
public protocol InboundAppServicesWorking: Working, AppServicesRegistering,
                                           AppServiceHandling, AppLifecycleObserving {
}
