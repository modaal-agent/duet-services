// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

#if os(iOS)

import SwiftUI
import UIKit

// The view layer's route to the theme: a view reads `@Environment(\.theme)`
// and calls `theme.color(.token)` / `theme.font(.token)`. No view takes a
// theming parameter, however deeply nested, and no view model carries one on
// behalf of its views.
//
// A SwiftUI environment value does not cross a UIKit boundary, so the theme is
// published once per SwiftUI tree — at the `UIHostingController` that roots it.
// Subclass `ThemedHostingController` and hand it the provider:
//
// ```swift
// final class SomeViewController: ThemedHostingController<SomeView> {
//   init(theme: ThemeProviding, viewState: SomeViewState) {
//     super.init(theme: theme, rootView: SomeView(viewState: viewState))
//   }
// }
// ```
//
// An app whose entire view tree hangs off ONE hosting controller publishes
// once instead, with `ThemeScope`:
//
// ```swift
// UIHostingController(rootView: ThemeScope(theme) { RootScreen() })
// ```
//
// Do not replace this with a custom UIKit trait bridged through
// `UITraitBridgedEnvironmentKey`. That bridge is compiled in only when the
// package DECLARING the conformance is built with an iOS 17 deployment target
// or higher — under a lower floor it compiles, the trait itself still stores
// and inherits, and every `@Environment(\.theme)` read silently returns the
// default below with no diagnostic at build or run time. Raising the iOS floor
// in the manifest to 17 raises it for every consumer of every product in this
// package, which SwiftPM enforces as a hard version-solve error.

// MARK: - The environment value

public extension EnvironmentValues {
  /// The theme the SwiftUI tree renders with.
  var theme: ThemeProviding {
    get { self[ThemeKey.self] }
    set { self[ThemeKey.self] = newValue }
  }
}

struct ThemeKey: EnvironmentKey {
  // Fallback for previews and for trees no hosting root published to; app code
  // sees the provider its hosting controller was handed. Themes and appearance
  // persist across launches, so this resolves to whatever the user last chose.
  //
  // The theme itself comes from the app's `ThemeDefaulting` conformance on
  // `ThemeDefaults` — this module names no concrete theme.
  //
  // `EnvironmentKey.defaultValue` is a nonisolated static requirement, so it
  // cannot be main-actor isolated. SwiftUI reads it during view updates on the
  // main actor, and the erased `ThemeProviding` surface exposes no mutation —
  // `ThemeProvidingUpdating` (the mutable half) never travels here.
  nonisolated(unsafe) static let defaultValue: ThemeProviding = {
    let defaults = ThemeDefaults().defaulting
    return ThemeProvider(
      persistentStorage: ThemePersistentStorage(),
      defaultTheme: defaults.defaultTheme(),
      defaultPreferredAppearance: defaults.defaultAppearance())
  }()
}

// MARK: - Publishing to a tree

/// Publishes a theme to one SwiftUI tree.
///
/// ```swift
/// ThemeScope(themeProvider) { SomeView(viewState: viewState) }
/// ```
///
/// Nesting one inside another re-publishes for the inner tree, which is how a
/// subtree renders on a different theme than the rest of the app.
public struct ThemeScope<Content: View>: View {
  private let theme: ThemeProviding
  private let content: Content

  public init(_ theme: ThemeProviding, @ViewBuilder content: () -> Content) {
    self.theme = theme
    self.content = content()
  }

  public var body: some View {
    content.environment(\.theme, theme)
  }
}

/// What a `ThemedHostingController` hosts. It has no reachable initializer, and
/// that is its job: `rootView` is typed as this, so a subclass cannot assign to
/// `rootView` at all and `themedRootView` is the only way to swap hosted
/// content. Both mistakes are compile errors rather than a silently unthemed —
/// or differently themed — subtree:
///
/// - `rootView = someView` — `cannot assign value of type 'SomeView' to type
///   'ThemedRootView<SomeView>'`
/// - `rootView = ThemedRootView(...)` — `initializer is inaccessible due to
///   'fileprivate' protection level`
///
/// One assignment still compiles, because the value on the right is already
/// constructed: `a.rootView = b.rootView` between two controllers of the same
/// `Content` carries B's publication into A. This module cannot close it —
/// `UIHostingController.rootView` is `public`, not `open`, so overriding its
/// setter here is rejected with `overriding non-open property outside of its
/// defining module`. Set hosted content through `themedRootView`, and never
/// read another controller's `rootView`; `ThemingTests` pins what the
/// transplant does.
public struct ThemedRootView<Content: View>: View {
  fileprivate let theme: ThemeProviding
  fileprivate let content: Content

  public var body: some View {
    ThemeScope(theme) { content }
  }
}

/// A `UIHostingController` that publishes a theme to the tree it hosts, so the
/// hosted view and everything below it resolve `@Environment(\.theme)` to the
/// provider passed here.
///
/// The generic parameter is the view being hosted — the wrapper stays out of
/// the subclass's type signature:
///
/// ```swift
/// final class SomeViewController: ThemedHostingController<SomeView> {
///   init(theme: ThemeProviding, viewState: SomeViewState) {
///     super.init(theme: theme, rootView: SomeView(viewState: viewState))
///   }
/// }
/// ```
open class ThemedHostingController<Content: View>: UIHostingController<ThemedRootView<Content>> {

  private let theme: ThemeProviding

  public init(theme: ThemeProviding, rootView: Content) {
    self.theme = theme
    super.init(rootView: ThemedRootView(theme: theme, content: rootView))
  }

  @MainActor required public dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The view this controller hosts. Assign to it exactly as you would assign
  /// `rootView` on a plain `UIHostingController` — the theme is re-published to
  /// the new tree. This is the only way to change the hosted content:
  ///
  /// ```swift
  /// themedRootView = SomeView(viewState: viewState).onFinish(handler)
  /// ```
  public var themedRootView: Content {
    get { rootView.content }
    set { rootView = ThemedRootView(theme: theme, content: newValue) }
  }
}

#endif
