// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

import UIKit

/// A color set to define colors based on light and dark appearances.
public struct ColorSet {
  let appearance: Appearance<UIColor>

  public init(_ appearance: Appearance<UIColor>) {
    self.appearance = appearance
  }
}

#endif
