// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

/// A preferred appearance to override system appearance.
public enum PreferredAppearance: Codable {
  /// An appearance that uses current system appearance.
  case system
  /// An appearance that uses light appearance.
  case light
  /// An appearance that uses dark appearance.
  case dark
}

#endif
