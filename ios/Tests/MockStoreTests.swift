import XCTest
@testable import MockStore

final class MockStoreTests: XCTestCase {
    func testNestedStableIDsAndRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try MockStore(directory: directory)
        let nested = try first.children(of: "folder-books").first { $0.name == "Notes" }
        XCTAssertEqual(nested?.id, "folder-notes")
        let file = try first.item("file-welcome")
        XCTAssertEqual(file?.parentID, nested?.id)
        let restarted = try MockStore(directory: directory)
        XCTAssertEqual(try restarted.item("file-welcome"), file)
        let copy = directory.appendingPathComponent("copy.txt")
        try restarted.materialize(id: "file-welcome", into: copy)
        XCTAssertEqual(try String(contentsOf: copy), "Hello from SUIZAI.\n")
    }

    func testMutationsPersistAndRejectUnsafeNames() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MockStore(directory: directory)
        let entry = try store.create(parentID: "folder-notes", name: "Draft.txt", isDirectory: false, contents: Data("a".utf8))
        XCTAssertThrowsError(try store.create(parentID: "folder-notes", name: "../escape", isDirectory: false))
        let moved = try store.modify(id: entry.id, parentID: "folder-books", name: "Final.txt", contents: Data("changed".utf8)).entry
        XCTAssertEqual(moved.id, entry.id)
        XCTAssertEqual(moved.revision, 2)
        let reopened = try MockStore(directory: directory)
        XCTAssertEqual(try reopened.children(of: "folder-books").first { $0.id == entry.id }?.size, 7)
        try reopened.delete(id: entry.id)
        XCTAssertNil(try reopened.item(entry.id))
    }

    func testChangesAreScopedPersistedAndReportMoveAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MockStore(directory: directory)
        let start = try store.currentAnchor()
        let entry = try store.create(parentID: "folder-notes", name: "New.txt", isDirectory: false)
        let afterCreate = try store.currentAnchor()
        XCTAssertEqual(try store.changes(after: start, in: "folder-notes").updates.map(\.id), [entry.id])
        XCTAssertTrue(try store.changes(after: start, in: "folder-books").updates.isEmpty)
        XCTAssertEqual(try store.changes(after: start, in: "working-set").updates.map(\.id), [entry.id])

        _ = try store.modify(id: entry.id, parentID: "folder-books", name: "Moved.txt", contents: nil)
        let reopened = try MockStore(directory: directory)
        XCTAssertEqual(try reopened.changes(after: afterCreate, in: "folder-notes").deletions, [entry.id])
        XCTAssertEqual(try reopened.changes(after: afterCreate, in: "folder-books").updates.map(\.id), [entry.id])
        XCTAssertEqual(try reopened.changes(after: afterCreate, in: "working-set").updates.map(\.id), [entry.id])

        let afterMove = try reopened.currentAnchor()
        try reopened.delete(id: entry.id)
        XCTAssertEqual(try reopened.changes(after: afterMove, in: "folder-books").deletions, [entry.id])
        XCTAssertEqual(try reopened.changes(after: afterMove, in: "working-set").deletions, [entry.id])
        XCTAssertTrue(try reopened.changes(after: afterMove, in: "folder-notes").deletions.isEmpty)
        let current = try reopened.currentAnchor()
        XCTAssertTrue(try reopened.changes(after: current, in: "folder-books").updates.isEmpty)
        XCTAssertTrue(try reopened.changes(after: current, in: "folder-books").deletions.isEmpty)
        XCTAssertThrowsError(try reopened.changes(after: Int.max, in: "folder-books"))
    }

    func testMetadataOnlyChangePreservesContentVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MockStore(directory: directory)
        let old = try XCTUnwrap(store.item("file-welcome"))
        let renamed = try store.modify(id: old.id, parentID: old.parentID, name: "Renamed.txt", contents: nil).entry
        XCTAssertEqual(renamed.contentRevision, old.contentRevision)
        XCTAssertGreaterThan(renamed.revision, old.revision)
        let rewritten = try store.modify(id: old.id, parentID: old.parentID, name: "Renamed.txt", contents: Data("new".utf8)).entry
        XCTAssertGreaterThan(rewritten.contentRevision, renamed.contentRevision)
    }

    func testMaterializedBytesMatchSnapshotDuringConcurrentWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MockStore(directory: directory)
        let file = try store.create(parentID: "folder-notes", name: "Concurrent.txt", isDirectory: false, contents: Data(repeating: 1, count: 1))
        let group = DispatchGroup()
        let failures = FailureBox()
        group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            for length in 1...100 {
                do { _ = try store.modify(id: file.id, parentID: file.parentID, name: file.name, contents: Data(repeating: UInt8(length), count: length)) }
                catch { failures.record(error) }
            }
        }
        group.enter()
        DispatchQueue.global().async {
            defer { group.leave() }
            for _ in 1...100 {
                let copy = directory.appendingPathComponent(UUID().uuidString)
                do {
                    let snapshot = try store.materialize(id: file.id, into: copy)
                    let bytes = try Data(contentsOf: copy)
                    if bytes.count != snapshot.size || bytes.contains(where: { $0 != bytes.first }) { failures.record(MockStoreError.invalidAnchor) }
                    try FileManager.default.removeItem(at: copy)
                } catch { failures.record(error) }
            }
        }
        group.wait()
        XCTAssertTrue(failures.errors.isEmpty, "\(failures.errors)")
    }
}

private final class FailureBox {
    private let lock = NSLock()
    private var failures: [Error] = []
    var errors: [Error] { lock.lock(); defer { lock.unlock() }; return failures }
    func record(_ error: Error) { lock.lock(); defer { lock.unlock() }; failures.append(error) }
}
