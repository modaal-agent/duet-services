// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.
//
// Based on https://github.com/dscyrescotti/SwiftTheming

#if os(iOS)

/// The app's default theme, registered by conformance rather than passed by
/// parameter: this module declares `ThemeDefaults` without conforming it, and
/// the app retroactively conforms it — the same registration idiom as
/// `Themeable`, which `Theme._themed()` resolves with `self as! Themeable`.
/// A conformance is a declaration linked into the binary, not a startup call:
/// there is no registration ordering, no global mutable state, and Xcode
/// previews and test hosts resolve it without running any app startup code.
///
/// ```swift
/// extension ThemeDefaults: ThemeDefaulting {
///     public func defaultTheme() -> Theme { .mainTheme }
/// }
/// ```
///
/// `defaultAppearance()` has a `.system` default; implement it only to choose
/// something else.
public protocol ThemeDefaulting {
    /// The theme a SwiftUI tree renders with when no hosting root published a
    /// provider and nothing is persisted — Xcode previews and unhosted trees.
    func defaultTheme() -> Theme

    /// The preferred appearance for the same fallback.
    func defaultAppearance() -> PreferredAppearance
}

extension ThemeDefaulting {
    public func defaultAppearance() -> PreferredAppearance {
        .system
    }
}

/// The registration point for `ThemeDefaulting` — see that protocol for the
/// contract and the four-line conformance. Declare exactly one conformance in
/// the app target, beside the app's `Themeable` conformance (the two share a
/// contract class: each is a declaration the theming layer resolves by cast,
/// and each crashes every themed render when missing). A test target that
/// renders unhosted trees declares its own test-local conformance.
public struct ThemeDefaults {
    public init() {}

    internal var defaulting: ThemeDefaulting {
        self as! ThemeDefaulting
    }
}

#endif
