// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

/// An abstraction layer to define themes based on theme asset.
public protocol Themeable {
    /// A method that return `Themed` object based on theme.
    /// - Returns: theme object
    func themed() -> Themed
}

#endif
