// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

import Foundation

/// Outbound pasteboard write — narrow on purpose (one seam per port).
///
/// sourcery: CreateMock
public protocol PasteboardWriting: AnyObject {
  func write(string: String)
}
