import XCTest
import Darwin
@testable import MockStore
import SuizaiBridge

final class FixtureFetchTests: XCTestCase {
    func testFixtureProjectionSingleItemChangesAndReservedRootName() throws {
        let (directory, store) = try workspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let zh = try XCTUnwrap(FixtureSettings.projectedEntry(enabled: true, locale: "zh-TW", nativeRootCollision: false))
        XCTAssertEqual(zh.parentID, MockStore.rootID)
        XCTAssertEqual(FixtureSettings.listedEntry(in: MockStore.rootID, fixture: zh)?.id, FixtureSettings.id)
        XCTAssertEqual(FixtureSettings.listedEntry(in: "working-set", fixture: zh)?.id, FixtureSettings.id)
        XCTAssertEqual(FixtureSettings.listedEntry(in: FixtureSettings.id, fixture: zh)?.id, FixtureSettings.id)
        XCTAssertNil(FixtureSettings.listedEntry(in: "folder-notes", fixture: zh))
        XCTAssertEqual(FixtureSettings.change(in: FixtureSettings.id, from: 0, fixture: zh).update?.id, FixtureSettings.id)
        XCTAssertNil(FixtureSettings.change(in: FixtureSettings.id, from: zh.contentRevision, fixture: zh).update)
        let en = FixtureSettings.entry(locale: "en")
        XCTAssertEqual(FixtureSettings.change(in: FixtureSettings.id, from: zh.contentRevision, fixture: en).update?.contentRevision, en.contentRevision)
        XCTAssertEqual(FixtureSettings.change(in: FixtureSettings.id, from: en.contentRevision, fixture: nil).deletion, FixtureSettings.id)
        XCTAssertEqual(FixtureSettings.change(in: FixtureSettings.id, from: 0, fixture: en).update?.id, FixtureSettings.id)
        XCTAssertNil(FixtureSettings.change(in: "folder-notes", from: 0, fixture: en).update)

        XCTAssertTrue(FixtureSettings.conflictsWithReservedName(parentID: MockStore.rootID, name: FixtureSettings.filename)) // create
        XCTAssertTrue(FixtureSettings.conflictsWithReservedName(parentID: MockStore.rootID, name: FixtureSettings.filename,
                                                                current: try store.item("file-welcome"))) // rename/move
        XCTAssertFalse(FixtureSettings.conflictsWithReservedName(parentID: "folder-notes", name: FixtureSettings.filename))
        let oldFile = try store.create(parentID: MockStore.rootID, name: FixtureSettings.filename, isDirectory: false)
        XCTAssertFalse(FixtureSettings.conflictsWithReservedName(parentID: MockStore.rootID, name: FixtureSettings.filename, current: oldFile))
        XCTAssertNil(FixtureSettings.projectedEntry(enabled: true, locale: "en", nativeRootCollision:
            try store.item(parentID: MockStore.rootID, name: FixtureSettings.filename) != nil))
        XCTAssertEqual(try store.item(oldFile.id), oldFile) // An older native file is preserved on enable.
        XCTAssertNil(FixtureSettings.projectedEntry(enabled: false, locale: "en", nativeRootCollision: false))
    }

    private func workspace() throws -> (URL, MockStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (directory, try MockStore(directory: directory))
    }

    private func awaitHandles(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(2)
        while suizai_fixture_active_handles() != expected && Date() < deadline { Thread.sleep(forTimeInterval: 0.005) }
        XCTAssertEqual(suizai_fixture_active_handles(), expected, file: file, line: line)
    }

    func testThreeLocalesAsynchronousSuccessAndNativeBaseline() throws {
        let (directory, store) = try workspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = ["zh-TW": "SUIZAI 共用核心測試檔案\n", "en": "SUIZAI shared core test file\n", "ja": "SUIZAI 共通コアのテストファイル\n"]
        for (locale, text) in expected {
            let destination = directory.appendingPathComponent(UUID().uuidString)
            let done = expectation(description: locale)
            done.assertForOverFulfill = true
            let progress = FixtureFetch.start(store: store, id: FixtureSettings.id, destination: destination,
                                              enabled: true, locale: locale, delay: 100) { url, entry, error in
                XCTAssertNil(error)
                XCTAssertEqual(url, destination)
                XCTAssertEqual(entry?.id, FixtureSettings.id)
                XCTAssertEqual(entry?.size, text.utf8.count)
                XCTAssertEqual(entry?.contentRevision, FixtureSettings.entry(locale: locale).contentRevision)
                XCTAssertEqual(try? String(contentsOf: destination), text)
                done.fulfill()
            }
            XCTAssertFalse(progress.isFinished)
            wait(for: [done], timeout: 3)
            XCTAssertTrue(progress.isFinished)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path)) // File Provider owns this URL after success.
            try FileManager.default.removeItem(at: destination)
            awaitHandles(0)
        }
        let native = directory.appendingPathComponent("native")
        let done = expectation(description: "native")
        _ = FixtureFetch.start(store: store, id: "file-welcome", destination: native,
                               enabled: false, locale: "zh-TW", delay: 0) { url, entry, error in
            XCTAssertNil(error)
            XCTAssertEqual(url, native)
            XCTAssertEqual(entry?.id, "file-welcome")
            done.fulfill()
        }
        wait(for: [done], timeout: 1)
        XCTAssertEqual(try String(contentsOf: native), "Hello from SUIZAI.\n")
    }

    func testCancellationBeforeDispatchDuringReadAndCompletionOnce() throws {
        let (directory, store) = try workspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let held = DispatchQueue(label: "held.fixture.queue")
        held.suspend()
        let before = directory.appendingPathComponent("before")
        let beforeDone = expectation(description: "before")
        beforeDone.assertForOverFulfill = true
        let first = FixtureFetch.start(store: store, id: FixtureSettings.id, destination: before,
                                       enabled: true, locale: "en", delay: 0, queue: held) { url, entry, error in
            XCTAssertNil(url); XCTAssertNil(entry); XCTAssertNotNil(error)
            beforeDone.fulfill()
        }
        first.cancel()
        held.resume()
        wait(for: [beforeDone], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: before.path))
        awaitHandles(0)

        let during = directory.appendingPathComponent("during")
        let duringDone = expectation(description: "during")
        duringDone.assertForOverFulfill = true
        let second = FixtureFetch.start(store: store, id: FixtureSettings.id, destination: during,
                                        enabled: true, locale: "ja", delay: 500) { url, entry, error in
            XCTAssertNil(url); XCTAssertNil(entry); XCTAssertNotNil(error)
            duringDone.fulfill()
        }
        awaitHandles(1)
        second.cancel()
        wait(for: [duringDone], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: during.path))
        awaitHandles(0)
        second.cancel() // A late cancellation cannot call completion again.
    }

    func testBridgeErrorRemovesTemporaryFile() throws {
        let (directory, store) = try workspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("error")
        try Data("stale".utf8).write(to: destination)
        let done = expectation(description: "invalid fixture")
        _ = FixtureFetch.start(store: store, id: FixtureSettings.id, destination: destination,
                               enabled: true, locale: "en", delay: 0, fixtureID: "missing") { url, entry, error in
            XCTAssertNil(url); XCTAssertNil(entry)
            XCTAssertEqual(error as? FixtureFetchError, .status(Int32(SUIZAI_INVALID_INPUT.rawValue)))
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        awaitHandles(0)
    }

    func testNativeAndBridgeWorkloadObservations() throws {
        let (directory, store) = try workspace()
        defer { try? FileManager.default.removeItem(at: directory) }
        for bridge in [false, true] {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            let beforeRSS = usage.ru_maxrss
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<100 {
                let destination = directory.appendingPathComponent("\(bridge)-\(index)")
                let done = expectation(description: "workload \(index)")
                _ = FixtureFetch.start(store: store, id: bridge ? FixtureSettings.id : "file-welcome", destination: destination,
                                       enabled: bridge, locale: "en", delay: 0) { url, _, error in
                    XCTAssertNotNil(url); XCTAssertNil(error)
                    done.fulfill()
                }
                wait(for: [done], timeout: 2)
                try FileManager.default.removeItem(at: destination)
            }
            getrusage(RUSAGE_SELF, &usage)
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            print("SUIZAI_METRIC host=macOS path=\(bridge ? "rust" : "native") operations=100 elapsed_ms=\(ms) peak_rss_before_bytes=\(beforeRSS) peak_rss_after_bytes=\(usage.ru_maxrss)")
        }
        awaitHandles(0)
    }
}
