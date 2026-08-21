// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

/// An empty asset for themes.
public struct EmptyAsset: ColorAssetable, FontAssetable, ImageAssetable, GradientAssetable { }

public extension Assetable where _ColorAsset == EmptyAsset {
    @discardableResult
    func colorSet(for: EmptyAsset) -> ColorSet {
        fatalError("You are accessing an empty color asset.")
    }
}

public extension Assetable where _FontAsset == EmptyAsset {
    @discardableResult
    func fontSet(for asset: EmptyAsset) -> FontSet {
        fatalError("You are accessing an empty font asset.")
    }
}

public extension Assetable where _ImageAsset == EmptyAsset {
    @discardableResult
    func imageSet(for asset: EmptyAsset) -> ImageSet {
        fatalError("You are accessing an empty image asset.")
    }
}

public extension Assetable where _GradientAsset == EmptyAsset {
    @discardableResult
    func gradientSet(for asset: EmptyAsset) -> GradientSet {
      fatalError("You are accessing an empty gradient asset.")
    }
}

#endif
