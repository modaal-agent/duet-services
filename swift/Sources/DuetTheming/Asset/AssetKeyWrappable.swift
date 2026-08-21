// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

/// An abstraction layer that helps to define any type of asset.
public protocol AssetKeyWrappable {
    func _colorSet(for asset: ColorAssetable) -> ColorSet
    func _fontSet(for asset: FontAssetable) -> FontSet
    func _imageSet(for asset: ImageAssetable) -> ImageSet
    func _gradientSet(for asset: GradientAssetable) -> GradientSet
}

#endif
