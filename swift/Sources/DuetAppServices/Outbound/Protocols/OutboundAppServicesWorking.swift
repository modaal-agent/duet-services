// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

// iOS-bound, so absent from the macOS host lane (whole-file-guarded by
// design): the composite carries `AudioSessionConfiguring`, whose members
// name `AVAudioApplication`. The narrow ports themselves are
// platform-neutral and stay compiled on every lane.
#if os(iOS)

import DuetShells
import Foundation

/// The composed outbound contract: everything the app asks OF the system —
/// opening URLs, the pasteboard, haptics, the audio session, and the two
/// permission prompts.
///
/// The composition root stores this and adopts it
/// (`host.adopt(outboundAppServices)`); features depend on the narrow ports
/// (`URLOpening`, `PasteboardReading`, …) instead, so a feature's test double
/// implements one method rather than eleven.
///
/// To add an outbound capability (biometric auth, the share sheet, screenshot
/// capture):
///
///   1. Declare a narrow port beside `URLOpening`, annotated
///      `sourcery: CreateMock`, with a doc comment stating its threading and
///      side-effect contract.
///   2. Compose it into this protocol.
///   3. Implement it in `OutboundAppServicesWorker`.
///   4. Expose it from the composition root as a narrow computed property.
///
/// Something the app RECEIVES rather than requests goes on
/// `InboundAppServicesWorking`, which is where `AppLifecycleObserving` lives.
///
/// NOT CreateMock-annotated: this file is platform-conditional, and a
/// generated mock is unconditional — the macOS host lane cannot compile it.
/// Depend on the narrow ports, each of which has its own generated double.
public protocol OutboundAppServicesWorking: Working, URLOpening,
                                            PasteboardReading, PasteboardWriting,
                                            HapticFeedbackProviding,
                                            AppTrackingAuthorizationRequesting,
                                            PushNotificationAuthorizationRequesting,
                                            AudioSessionConfiguring {
}

#endif
