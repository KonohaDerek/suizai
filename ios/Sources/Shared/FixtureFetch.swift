import Foundation
#if SWIFT_PACKAGE
import SuizaiBridge
#endif

enum FixtureSettings {
    static let group = "group.dev.suizai.phase0"
    static let id = "bridge-welcome"
    static let filename = "SUIZAI-Rust.txt"
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static var enabled: Bool { defaults?.bool(forKey: "rustFixtureEnabled") ?? false }
    static var locale: String { defaults?.string(forKey: "rustFixtureLocale") ?? "zh-TW" }
    static var delay: UInt32 { UInt32(min(500, max(0, defaults?.integer(forKey: "rustFixtureDelayMS") ?? 0))) }
    static func entry(locale: String) -> MockEntry {
        let text: String
        let contentRevision: Int
        if locale == "en" || locale.hasPrefix("en-") {
            text = "SUIZAI shared core test file\n"; contentRevision = 2
        } else if locale == "ja" || locale.hasPrefix("ja-") {
            text = "SUIZAI 共通コアのテストファイル\n"; contentRevision = 3
        } else {
            text = "SUIZAI 共用核心測試檔案\n"; contentRevision = 1
        }
        return MockEntry(id: id, parentID: MockStore.rootID, name: filename, isDirectory: false,
                         revision: 1, contentRevision: contentRevision, size: text.utf8.count)
    }

    static func projectedEntry(enabled: Bool, locale: String, nativeRootCollision: Bool) -> MockEntry? {
        enabled && !nativeRootCollision ? entry(locale: locale) : nil
    }

    static func conflictsWithReservedName(parentID: String, name: String, current: MockEntry? = nil) -> Bool {
        parentID == MockStore.rootID && name == filename &&
            (current?.parentID != MockStore.rootID || current?.name != filename)
    }

    static func listedEntry(in containerID: String, fixture: MockEntry?) -> MockEntry? {
        guard containerID == MockStore.rootID || containerID == "working-set" || containerID == id else { return nil }
        return fixture
    }

    static func change(in containerID: String, from oldState: Int, fixture: MockEntry?) -> (update: MockEntry?, deletion: String?) {
        guard containerID == MockStore.rootID || containerID == "working-set" || containerID == id else { return (nil, nil) }
        guard oldState != (fixture?.contentRevision ?? 0) else { return (nil, nil) }
        return fixture.map { ($0, nil) } ?? (nil, id)
    }
}

enum FixtureFetchError: Error, Equatable {
    case status(Int32)
}

/// The same entry point used by File Provider and host tests. Only the fixture takes the worker queue.
enum FixtureFetch {
    private static let workerQueue = DispatchQueue(label: "dev.suizai.fixture-fetch", qos: .userInitiated)
    @discardableResult static func start(store: MockStore, id: String, destination: URL,
                                          enabled: Bool, locale: String, delay: UInt32,
                                          fixtureID: String = FixtureSettings.id,
                                          queue: DispatchQueue = FixtureFetch.workerQueue,
                                          completion: @escaping (URL?, MockEntry?, Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        guard enabled && id == FixtureSettings.id else {
            do {
                let entry = try store.materialize(id: id, into: destination)
                progress.completedUnitCount = 1
                completion(destination, entry, nil)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                completion(nil, nil, error)
            }
            return progress
        }

        let state = FetchState(progress: progress, destination: destination, completion: completion)
        progress.cancellationHandler = { state.cancel() }
        queue.async {
            state.run(locale: locale, delay: delay, fixtureID: fixtureID)
        }
        return progress
    }
}

private final class FetchState {
    private let lock = NSLock()
    private let progress: Progress
    private let destination: URL
    private let completion: (URL?, MockEntry?, Error?) -> Void
    private var handle: UInt64 = 0
    private var cancelled = false
    private var finished = false

    init(progress: Progress, destination: URL, completion: @escaping (URL?, MockEntry?, Error?) -> Void) {
        self.progress = progress
        self.destination = destination
        self.completion = completion
    }

    func cancel() {
        lock.lock()
        if finished { lock.unlock(); return }
        cancelled = true
        let current = handle
        lock.unlock()
        if current != 0 { _ = suizai_fixture_cancel(current) }
    }

    func run(locale: String, delay: UInt32, fixtureID: String) {
        lock.lock()
        let cancelledBeforeOpen = cancelled
        lock.unlock()
        if cancelledBeforeOpen { finish(error: CocoaError(.userCancelled)); return }

        var opened: UInt64 = 0
        let status = fixtureID.utf8CString.withUnsafeBufferPointer { id in
            locale.utf8CString.withUnsafeBufferPointer { language in
                suizai_fixture_open(UnsafeRawPointer(id.baseAddress!).assumingMemoryBound(to: UInt8.self), id.count - 1,
                                    UnsafeRawPointer(language.baseAddress!).assumingMemoryBound(to: UInt8.self), language.count - 1,
                                    delay, &opened)
            }
        }
        guard status == SUIZAI_OK.rawValue else { finish(error: FixtureFetchError.status(status)); return }
        lock.lock()
        handle = opened
        let cancelNow = cancelled
        lock.unlock()
        if cancelNow { _ = suizai_fixture_cancel(opened) }
        var bytes = [UInt8](repeating: 0, count: 65_536)
        var count = 0
        let readStatus = bytes.withUnsafeMutableBufferPointer {
            suizai_fixture_read(opened, $0.baseAddress, $0.count, &count)
        }
        var terminalError: Error?
        if readStatus != SUIZAI_OK.rawValue {
            terminalError = readStatus == SUIZAI_CANCELLED.rawValue ? CocoaError(.userCancelled) : FixtureFetchError.status(readStatus)
        } else {
            do { try Data(bytes.prefix(count)).write(to: destination, options: .atomic) }
            catch { terminalError = error }
        }
        lock.lock()
        handle = 0
        lock.unlock()
        _ = suizai_fixture_release(opened)
        finish(entry: terminalError == nil ? FixtureSettings.entry(locale: locale) : nil, error: terminalError)
    }

    private func finish(entry: MockEntry? = nil, error: Error? = nil) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let wasCancelled = cancelled
        lock.unlock()
        progress.cancellationHandler = nil
        if error != nil || wasCancelled { try? FileManager.default.removeItem(at: destination) }
        if let error { completion(nil, nil, error) }
        else if wasCancelled { completion(nil, nil, CocoaError(.userCancelled)) }
        else {
            progress.completedUnitCount = 1
            completion(destination, entry, nil)
        }
    }
}
