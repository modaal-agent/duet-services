// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

import UIKit
import SwiftUI

/// A color set to define colors based on light and dark appearances.
public struct GradientSet {
  let appearance: Appearance<Gradient>

  public init(_ appearance: Appearance<Gradient>) {
    self.appearance = appearance
  }
}

#endif
