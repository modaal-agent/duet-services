// Generated using Sourcery 2.3.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import Analytics
import AppServices
import Combine
import Diagnostics
import DuetShells
import Foundation

// MARK: - AnalyticsConsentStoring
final class AnalyticsConsentStoringMock: AnalyticsConsentStoring {

    // MARK: - Variables
    var isEnabled: Bool = false {
        didSet {
            isEnabledSetCount += 1
        }
    }
    var isEnabledSetCount: Int = 0
    var isEnabledPublisher: AnyPublisher<Bool, Never> {
        isEnabledPublisherGetCount += 1
        if let handler = isEnabledPublisherGetHandler {
            return handler()
        }
        return isEnabledPublisherSubject.eraseToAnyPublisher()
    }
    var isEnabledPublisherGetCount: Int = 0
    var isEnabledPublisherGetHandler: (() -> AnyPublisher<Bool, Never>)? = nil
    lazy var isEnabledPublisherSubject = PassthroughSubject<Bool, Never>()
}

// MARK: - AppServiceURLHandling
@MainActor
final class AppServiceURLHandlingMock: AppServiceURLHandling {

    // MARK: - Methods
    func openURLs(_ urls: [URL]) {
        openURLsCallCount += 1
        openURLsArgs.append(urls)
        if let __openURLsHandler = self.openURLsHandler {
            __openURLsHandler(urls)
        }
    }
    var openURLsCallCount: Int = 0
    var openURLsArgs: [[URL]] = []
    var openURLsHandler: ((_ urls: [URL]) -> ())? = nil
}

// MARK: - AppServicesRegistrationSettling
@MainActor
final class AppServicesRegistrationSettlingMock: AppServicesRegistrationSettling {

    // MARK: - Methods
    func handlersDidRegister() {
        handlersDidRegisterCallCount += 1
        if let __handlersDidRegisterHandler = self.handlersDidRegisterHandler {
            __handlersDidRegisterHandler()
        }
    }
    var handlersDidRegisterCallCount: Int = 0
    var handlersDidRegisterHandler: (() -> ())? = nil
}

// MARK: - AppServicesURLHandlerRegistering
@MainActor
final class AppServicesURLHandlerRegisteringMock: AppServicesURLHandlerRegistering {

    // MARK: - Methods
    func registerURLHandler(_ handler: URLHandling, priority: AppServicePriority) -> AnyCancellable {
        registerURLHandlerCallCount += 1
        registerURLHandlerArgs.append((handler: handler, priority: priority))
        if let __registerURLHandlerHandler = self.registerURLHandlerHandler {
            return __registerURLHandlerHandler(handler, priority)
        }
        return AnyCancellable { [weak self] in
            self?.registerURLHandlerCancelCallCount += 1
            self?.registerURLHandlerCancelHandler?()
        }
    }
    var registerURLHandlerCallCount: Int = 0
    var registerURLHandlerArgs: [(handler: URLHandling, priority: AppServicePriority)] = []
    var registerURLHandlerHandler: ((_ handler: URLHandling, _ priority: AppServicePriority) -> (AnyCancellable))? = nil
    var registerURLHandlerCancelCallCount: Int = 0
    var registerURLHandlerCancelHandler: (() -> ())? = nil
}

// MARK: - Diagnostics
@MainActor
final class DiagnosticsMock: Diagnostics {

    // MARK: - Variables
    var logs: AnyPublisher<(level: LogLevel, message: String), Never> {
        logsGetCount += 1
        if let handler = logsGetHandler {
            return handler()
        }
        return logsSubject.eraseToAnyPublisher()
    }
    var logsGetCount: Int = 0
    var logsGetHandler: (() -> AnyPublisher<(level: LogLevel, message: String), Never>)? = nil
    lazy var logsSubject = PassthroughSubject<(level: LogLevel, message: String), Never>()

    // MARK: - Methods
    func exception(_ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String) {
        exceptionCallCount += 1
        exceptionArgs.append((error: error, userInfo: userInfo, file: file, line: line, function: function))
        if let __exceptionHandler = self.exceptionHandler {
            __exceptionHandler(error, userInfo, file, line, function)
        }
    }
    var exceptionCallCount: Int = 0
    var exceptionArgs: [(error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String)] = []
    var exceptionHandler: ((_ error: Error, _ userInfo: [String: Any]?, _ file: String, _ line: Int, _ function: String) -> ())? = nil
    func log(level: LogLevel, _ message: String) {
        logCallCount += 1
        logArgs.append((level: level, message: message))
        if let __logHandler = self.logHandler {
            __logHandler(level, message)
        }
    }
    var logCallCount: Int = 0
    var logArgs: [(level: LogLevel, message: String)] = []
    var logHandler: ((_ level: LogLevel, _ message: String) -> ())? = nil
    func setCustomValue(_ value: Any?, forKey key: String) {
        setCustomValueCallCount += 1
        setCustomValueArgs.append((value: value, key: key))
        if let __setCustomValueHandler = self.setCustomValueHandler {
            __setCustomValueHandler(value, key)
        }
    }
    var setCustomValueCallCount: Int = 0
    var setCustomValueArgs: [(value: Any?, key: String)] = []
    var setCustomValueHandler: ((_ value: Any?, _ key: String) -> ())? = nil
    func setUserID(_ userID: String?) {
        setUserIDCallCount += 1
        setUserIDArgs.append(userID)
        if let __setUserIDHandler = self.setUserIDHandler {
            __setUserIDHandler(userID)
        }
    }
    var setUserIDCallCount: Int = 0
    var setUserIDArgs: [String?] = []
    var setUserIDHandler: ((_ userID: String?) -> ())? = nil
}

// MARK: - DiagnosticsLogging
@MainActor
final class DiagnosticsLoggingMock: DiagnosticsLogging {

    // MARK: - Methods
    func exception(_ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String) {
        exceptionCallCount += 1
        exceptionArgs.append((error: error, userInfo: userInfo, file: file, line: line, function: function))
        if let __exceptionHandler = self.exceptionHandler {
            __exceptionHandler(error, userInfo, file, line, function)
        }
    }
    var exceptionCallCount: Int = 0
    var exceptionArgs: [(error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String)] = []
    var exceptionHandler: ((_ error: Error, _ userInfo: [String: Any]?, _ file: String, _ line: Int, _ function: String) -> ())? = nil
    func log(level: LogLevel, _ message: String) {
        logCallCount += 1
        logArgs.append((level: level, message: message))
        if let __logHandler = self.logHandler {
            __logHandler(level, message)
        }
    }
    var logCallCount: Int = 0
    var logArgs: [(level: LogLevel, message: String)] = []
    var logHandler: ((_ level: LogLevel, _ message: String) -> ())? = nil
}

// MARK: - DiagnosticsLogsObserving
@MainActor
final class DiagnosticsLogsObservingMock: DiagnosticsLogsObserving {

    // MARK: - Variables
    var logs: AnyPublisher<(level: LogLevel, message: String), Never> {
        logsGetCount += 1
        if let handler = logsGetHandler {
            return handler()
        }
        return logsSubject.eraseToAnyPublisher()
    }
    var logsGetCount: Int = 0
    var logsGetHandler: (() -> AnyPublisher<(level: LogLevel, message: String), Never>)? = nil
    lazy var logsSubject = PassthroughSubject<(level: LogLevel, message: String), Never>()

    // MARK: - Methods
    func exception(_ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String) {
        exceptionCallCount += 1
        exceptionArgs.append((error: error, userInfo: userInfo, file: file, line: line, function: function))
        if let __exceptionHandler = self.exceptionHandler {
            __exceptionHandler(error, userInfo, file, line, function)
        }
    }
    var exceptionCallCount: Int = 0
    var exceptionArgs: [(error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String)] = []
    var exceptionHandler: ((_ error: Error, _ userInfo: [String: Any]?, _ file: String, _ line: Int, _ function: String) -> ())? = nil
    func log(level: LogLevel, _ message: String) {
        logCallCount += 1
        logArgs.append((level: level, message: message))
        if let __logHandler = self.logHandler {
            __logHandler(level, message)
        }
    }
    var logCallCount: Int = 0
    var logArgs: [(level: LogLevel, message: String)] = []
    var logHandler: ((_ level: LogLevel, _ message: String) -> ())? = nil
}

// MARK: - DiagnosticsWorking
@MainActor
final class DiagnosticsWorkingMock: DiagnosticsWorking, @unchecked Sendable {

    // MARK: - Variables
    var logs: AnyPublisher<(level: LogLevel, message: String), Never> {
        logsGetCount += 1
        if let handler = logsGetHandler {
            return handler()
        }
        return logsSubject.eraseToAnyPublisher()
    }
    var logsGetCount: Int = 0
    var logsGetHandler: (() -> AnyPublisher<(level: LogLevel, message: String), Never>)? = nil
    lazy var logsSubject = PassthroughSubject<(level: LogLevel, message: String), Never>()

    // MARK: - Methods
    func exception(_ error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String) {
        exceptionCallCount += 1
        exceptionArgs.append((error: error, userInfo: userInfo, file: file, line: line, function: function))
        if let __exceptionHandler = self.exceptionHandler {
            __exceptionHandler(error, userInfo, file, line, function)
        }
    }
    var exceptionCallCount: Int = 0
    var exceptionArgs: [(error: Error, userInfo: [String: Any]?, file: String, line: Int, function: String)] = []
    var exceptionHandler: ((_ error: Error, _ userInfo: [String: Any]?, _ file: String, _ line: Int, _ function: String) -> ())? = nil
    func log(level: LogLevel, _ message: String) {
        logCallCount += 1
        logArgs.append((level: level, message: message))
        if let __logHandler = self.logHandler {
            __logHandler(level, message)
        }
    }
    var logCallCount: Int = 0
    var logArgs: [(level: LogLevel, message: String)] = []
    var logHandler: ((_ level: LogLevel, _ message: String) -> ())? = nil
    func run() async {
        runCallCount += 1
        if let __runHandler = self.runHandler {
            await __runHandler()
        }
    }
    var runCallCount: Int = 0
    var runHandler: (() async -> ())? = nil
    func setCustomValue(_ value: Any?, forKey key: String) {
        setCustomValueCallCount += 1
        setCustomValueArgs.append((value: value, key: key))
        if let __setCustomValueHandler = self.setCustomValueHandler {
            __setCustomValueHandler(value, key)
        }
    }
    var setCustomValueCallCount: Int = 0
    var setCustomValueArgs: [(value: Any?, key: String)] = []
    var setCustomValueHandler: ((_ value: Any?, _ key: String) -> ())? = nil
    func setHooks(_ hooks: DiagnosticsHooks) {
        setHooksCallCount += 1
        setHooksArgs.append(hooks)
        if let __setHooksHandler = self.setHooksHandler {
            __setHooksHandler(hooks)
        }
    }
    var setHooksCallCount: Int = 0
    var setHooksArgs: [DiagnosticsHooks] = []
    var setHooksHandler: ((_ hooks: DiagnosticsHooks) -> ())? = nil
    func setUserID(_ userID: String?) {
        setUserIDCallCount += 1
        setUserIDArgs.append(userID)
        if let __setUserIDHandler = self.setUserIDHandler {
            __setUserIDHandler(userID)
        }
    }
    var setUserIDCallCount: Int = 0
    var setUserIDArgs: [String?] = []
    var setUserIDHandler: ((_ userID: String?) -> ())? = nil
}

// MARK: - HapticFeedbackProviding
final class HapticFeedbackProvidingMock: HapticFeedbackProviding {

    // MARK: - Methods
    func impactHeavy() {
        impactHeavyCallCount += 1
        if let __impactHeavyHandler = self.impactHeavyHandler {
            __impactHeavyHandler()
        }
    }
    var impactHeavyCallCount: Int = 0
    var impactHeavyHandler: (() -> ())? = nil
    func impactLight() {
        impactLightCallCount += 1
        if let __impactLightHandler = self.impactLightHandler {
            __impactLightHandler()
        }
    }
    var impactLightCallCount: Int = 0
    var impactLightHandler: (() -> ())? = nil
    func impactMedium() {
        impactMediumCallCount += 1
        if let __impactMediumHandler = self.impactMediumHandler {
            __impactMediumHandler()
        }
    }
    var impactMediumCallCount: Int = 0
    var impactMediumHandler: (() -> ())? = nil
    func impactSoft() {
        impactSoftCallCount += 1
        if let __impactSoftHandler = self.impactSoftHandler {
            __impactSoftHandler()
        }
    }
    var impactSoftCallCount: Int = 0
    var impactSoftHandler: (() -> ())? = nil
}

// MARK: - PasteboardReading
final class PasteboardReadingMock: PasteboardReading {

    // MARK: - Methods
    func readString() -> String? {
        readStringCallCount += 1
        if let __readStringHandler = self.readStringHandler {
            return __readStringHandler()
        }
        return nil
    }
    var readStringCallCount: Int = 0
    var readStringHandler: (() -> (String?))? = nil
}

// MARK: - PasteboardWriting
final class PasteboardWritingMock: PasteboardWriting {

    // MARK: - Methods
    func write(string: String) {
        writeCallCount += 1
        writeArgs.append(string)
        if let __writeHandler = self.writeHandler {
            __writeHandler(string)
        }
    }
    var writeCallCount: Int = 0
    var writeArgs: [String] = []
    var writeHandler: ((_ string: String) -> ())? = nil
}

// MARK: - URLHandling
final class URLHandlingMock: URLHandling {

    // MARK: - Methods
    func canHandleOpenUrl(_ url: URL) -> Bool {
        canHandleOpenUrlCallCount += 1
        canHandleOpenUrlArgs.append(url)
        if let __canHandleOpenUrlHandler = self.canHandleOpenUrlHandler {
            return __canHandleOpenUrlHandler(url)
        }
        return false
    }
    var canHandleOpenUrlCallCount: Int = 0
    var canHandleOpenUrlArgs: [URL] = []
    var canHandleOpenUrlHandler: ((_ url: URL) -> (Bool))? = nil
    func handleOpenUrl(_ url: URL) {
        handleOpenUrlCallCount += 1
        handleOpenUrlArgs.append(url)
        if let __handleOpenUrlHandler = self.handleOpenUrlHandler {
            __handleOpenUrlHandler(url)
        }
    }
    var handleOpenUrlCallCount: Int = 0
    var handleOpenUrlArgs: [URL] = []
    var handleOpenUrlHandler: ((_ url: URL) -> ())? = nil
}

// MARK: - URLOpening
final class URLOpeningMock: URLOpening {

    // MARK: - Methods
    func open(_ url: URL) {
        openCallCount += 1
        openArgs.append(url)
        if let __openHandler = self.openHandler {
            __openHandler(url)
        }
    }
    var openCallCount: Int = 0
    var openArgs: [URL] = []
    var openHandler: ((_ url: URL) -> ())? = nil
}
