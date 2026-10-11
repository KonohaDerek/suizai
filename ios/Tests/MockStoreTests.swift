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
        let moved = try store.modify(id: entry.id, parentID: "folder-books", name: "Final.txt", contents: Data("changed".utf8))
        XCTAssertEqual(moved.id, entry.id)
        XCTAssertEqual(moved.revision, 2)
        let reopened = try MockStore(directory: directory)
        XCTAssertEqual(try reopened.children(of: "folder-books").first { $0.id == entry.id }?.size, 7)
        try reopened.delete(id: entry.id)
        XCTAssertNil(try reopened.item(entry.id))
    }
}
