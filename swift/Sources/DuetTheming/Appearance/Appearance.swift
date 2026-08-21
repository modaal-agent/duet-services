// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

import UIKit

public enum Appearance<T> {
  case `static`(T)
  case dynamic((UITraitCollection) -> T)
  case auto(light: T, dark: T)
}

#endif
