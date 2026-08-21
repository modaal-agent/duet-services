// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

import UIKit

/// A image set to define images based on light and dark appearances.
public struct ImageSet {
  let appearance: Appearance<UIImage>

  public init(_ appearance: Appearance<UIImage>) {
    self.appearance = appearance
  }
}

#endif
