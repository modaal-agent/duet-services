// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

import UIKit

public struct FontMetrics {
  public let pointSize: CGFloat
  public let lineHeight: CGFloat?
  public let letterSpacing: LetterSpacing

  public init(pointSize: CGFloat, lineHeight: CGFloat?, letterSpacing: LetterSpacing) {
    self.pointSize = pointSize
    self.lineHeight = lineHeight
    self.letterSpacing = letterSpacing
  }
}

/// A font set to define fonts based on light and dark appearances.
public struct FontSet {
  public let appearance: Appearance<UIFont>
  public let fontMetrics: FontMetrics

  public init(_ appearance: Appearance<UIFont>, fontMetrics: FontMetrics) {
    self.appearance = appearance
    self.fontMetrics = fontMetrics
  }
}

public enum LetterSpacing {
  case px(CGFloat)
  case pct(CGFloat)
}

public extension LetterSpacing {
  func toPoints(_ pointSize: CGFloat) -> CGFloat {
    switch self {
    case .px(let kern): return kern
    case .pct(let pct): return pointSize * pct / 100.0
    }
  }
}

public extension FloatLiteralType {
  var px: LetterSpacing { .px(self) }
  var pct: LetterSpacing { .pct(self) }
}

#endif
