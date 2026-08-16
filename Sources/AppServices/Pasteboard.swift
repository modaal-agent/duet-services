// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Outbound pasteboard write — narrow on purpose (one seam per port).
///
/// sourcery: CreateMock
public protocol PasteboardWriting: AnyObject {
  func write(string: String)
}

/// Inward pasteboard read, split from writing so consumers declare exactly
/// the capability they use (reading prompts the paste banner on iOS).
///
/// sourcery: CreateMock
public protocol PasteboardReading: AnyObject {
  func readString() -> String?
}
