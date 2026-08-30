// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

#if os(iOS)

import DuetTheming
import SwiftUI
import UIKit
import XCTest

/// The test-local theme the suite publishes and resolves. The environment
/// tests compare provider IDENTITY only, so the theme never resolves an
/// asset and needs no `Themeable` body.
private extension Theme {
  static let environmentTest = Theme(key: "environmentTest")
}

/// The test-local registration `ThemeKey.defaultValue` resolves — the same
/// pattern an app target uses (one `ThemeDefaulting` conformance beside its
/// `Themeable` conformance), declared here because a test host runs no app
/// startup code and links no app target.
extension ThemeDefaults: ThemeDefaulting {
  public func defaultTheme() -> Theme { .environmentTest }
}

/// In-memory persistence so tests never touch UserDefaults.
private final class InMemoryThemeStorage: ThemeProviderPersisting {
  private var store: [String: Data] = [:]

  func get<T: Codable>(_ type: T.Type, key: String) -> T? {
    store[key].flatMap { try? JSONDecoder().decode(T.self, from: $0) }
  }

  func set<T: Codable>(_ value: T, key: String) {
    store[key] = try? JSONEncoder().encode(value)
  }
}

/// Records which provider a view resolved, so a test can assert on a value
/// that only exists during a SwiftUI update. `ThemeProviding` is not
/// `Equatable`, so identity is what distinguishes one provider from another —
/// which the protocol's `AnyObject` constraint is what makes sound.
private final class ThemeRecorder {
  var resolved: ObjectIdentifier?
}

/// A leaf two levels below the hosted root, declaring no theming parameter.
private struct RecordingLeaf: View {
  let recorder: ThemeRecorder
  @Environment(\.theme) private var theme

  var body: some View {
    recorder.resolved = ObjectIdentifier(theme)
    return Color.clear
  }
}

private struct RecordingRoot: View {
  let recorder: ThemeRecorder
  var body: some View { VStack { RecordingLeaf(recorder: recorder) } }
}

/// The documented subclass, written exactly as `ThemeEnvironment.swift`'s
/// example writes it. It exists so the example is compiled: a subclass that
/// declares only its own initializer does not build, because
/// `UIHostingController.init(coder:)` is `required` and propagates down every
/// subclass in the chain.
private final class RecordingViewController: ThemedHostingController<RecordingRoot> {
  init(theme: ThemeProviding, recorder: ThemeRecorder) {
    super.init(theme: theme, rootView: RecordingRoot(recorder: recorder))
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// The contract the theming layer publishes on: the provider handed to a
/// hosting root reaches every view in the tree it hosts, however deep, and a
/// view declares nothing to receive it.
@MainActor
final class ThemeEnvironmentTests: XCTestCase {

  private var windows: [UIWindow] = []

  override func tearDown() {
    for window in windows {
      window.rootViewController = nil
      window.isHidden = true
    }
    windows = []
    super.tearDown()
  }

  private func makeProvider() -> ThemeProvider {
    ThemeProvider(
      persistentStorage: InMemoryThemeStorage(),
      defaultTheme: .environmentTest,
      defaultPreferredAppearance: .system)
  }

  /// Mounts `hosting` under a plain root view controller that carries no
  /// theming of its own, then renders.
  private func mount(_ hosting: UIViewController) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let root = UIViewController()
    window.rootViewController = root
    root.addChild(hosting)
    root.view.addSubview(hosting.view)
    hosting.view.frame = root.view.bounds
    hosting.didMove(toParent: root)
    windows.append(window)

    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
  }

  func testThemedHostingControllerReachesADeepView() {
    let recorder = ThemeRecorder()
    let provider = makeProvider()

    mount(ThemedHostingController(
      theme: provider,
      rootView: RecordingRoot(recorder: recorder)))

    XCTAssertEqual(recorder.resolved, ObjectIdentifier(provider))
  }

  /// The subclass route the documentation prescribes, mounted and rendered:
  /// a subclass publishes to its tree exactly as the direct construction
  /// above does.
  func testASubclassPublishesToItsTree() {
    let recorder = ThemeRecorder()
    let provider = makeProvider()

    mount(RecordingViewController(theme: provider, recorder: recorder))

    XCTAssertEqual(recorder.resolved, ObjectIdentifier(provider))
  }

  func testThemeScopeReachesADeepView() {
    let recorder = ThemeRecorder()
    let provider = makeProvider()

    mount(UIHostingController(
      rootView: ThemeScope(provider) { RecordingRoot(recorder: recorder) }))

    XCTAssertEqual(recorder.resolved, ObjectIdentifier(provider))
  }

  /// A nested scope re-publishes: the innermost publication wins for the tree
  /// it wraps, which is how one subtree renders on a different theme.
  func testANestedScopeOverridesTheOuterTheme() {
    let recorder = ThemeRecorder()
    let outer = makeProvider()
    let inner = makeProvider()

    mount(UIHostingController(rootView: ThemeScope(outer) {
      ThemeScope(inner) { RecordingRoot(recorder: recorder) }
    }))

    XCTAssertEqual(recorder.resolved, ObjectIdentifier(inner))
  }

  /// Assigning the hosted view re-publishes to the new tree, so a hosting
  /// controller that sets its content after `init` keeps its theme.
  func testAssigningThemedRootViewRepublishes() {
    let first = ThemeRecorder()
    let second = ThemeRecorder()
    let provider = makeProvider()
    let hosting = ThemedHostingController(
      theme: provider,
      rootView: RecordingRoot(recorder: first))

    mount(hosting)
    hosting.themedRootView = RecordingRoot(recorder: second)
    hosting.view.setNeedsLayout()
    hosting.view.layoutIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    XCTAssertEqual(second.resolved, ObjectIdentifier(provider))
  }

  /// A tree nobody published to renders on the key's default rather than
  /// failing — what previews rely on.
  func testUnpublishedTreeFallsBackToTheDefault() {
    let recorder = ThemeRecorder()
    let provider = makeProvider()

    mount(UIHostingController(rootView: RecordingRoot(recorder: recorder)))

    XCTAssertNotNil(recorder.resolved)
    XCTAssertNotEqual(recorder.resolved, ObjectIdentifier(provider))
  }

  /// A SwiftUI environment value does not cross a UIKit boundary: a hosting
  /// controller nested inside a themed one publishes nothing to its own tree,
  /// which is why EVERY hosting root takes the provider.
  func testANestedHostingControllerDoesNotInheritTheTheme() {
    let recorder = ThemeRecorder()
    let provider = makeProvider()

    let inner = UIHostingController(rootView: RecordingRoot(recorder: recorder))
    let outer = ThemedHostingController(theme: provider, rootView: Color.clear)
    outer.addChild(inner)
    outer.view.addSubview(inner.view)
    inner.view.frame = outer.view.bounds
    inner.didMove(toParent: outer)

    mount(outer)

    XCTAssertNotNil(recorder.resolved)
    XCTAssertNotEqual(recorder.resolved, ObjectIdentifier(provider))
  }

  /// The one route around the construction guard: the right-hand value is
  /// already built, so `a.rootView = b.rootView` compiles and hands A the
  /// theme B publishes. `UIHostingController.rootView` is `public`, not
  /// `open`, so Theming cannot override the setter to re-wrap. Set content
  /// through `themedRootView`; never read another controller's `rootView`.
  func testAnotherControllersRootViewCarriesItsOwnTheme() {
    let recorder = ThemeRecorder()
    let mine = makeProvider()
    let theirs = makeProvider()

    let source = ThemedHostingController(
      theme: theirs, rootView: RecordingRoot(recorder: recorder))
    let target = ThemedHostingController(
      theme: mine, rootView: RecordingRoot(recorder: ThemeRecorder()))
    target.rootView = source.rootView

    mount(target)

    XCTAssertEqual(recorder.resolved, ObjectIdentifier(theirs))
    XCTAssertNotEqual(recorder.resolved, ObjectIdentifier(mine))
  }
}

#endif
