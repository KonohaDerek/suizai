import Foundation
import Darwin

struct MockEntry: Codable, Equatable {
    let id: String
    var parentID: String
    var name: String
    var isDirectory: Bool
    var revision: Int
    var size: Int
}

enum MockStoreError: Error {
    case notFound, notDirectory, invalidName, duplicateName, nonEmptyDirectory
}

/// A small, process-independent mock catalog. The lock protects app/extension writers.
final class MockStore {
    static let rootID = "root"
    private let directory: URL
    private var catalogURL: URL { directory.appendingPathComponent("catalog.json") }
    private var lockURL: URL { directory.appendingPathComponent("catalog.lock") }
    private var contentDirectory: URL { directory.appendingPathComponent("content", isDirectory: true) }

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contentDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: catalogURL.path) {
            try locked {
                if !FileManager.default.fileExists(atPath: catalogURL.path) {
                    let entries = [MockEntry(id: "folder-books", parentID: Self.rootID, name: "Books", isDirectory: true, revision: 1, size: 0),
                                   MockEntry(id: "folder-notes", parentID: "folder-books", name: "Notes", isDirectory: true, revision: 1, size: 0),
                                   MockEntry(id: "file-welcome", parentID: "folder-notes", name: "Welcome.txt", isDirectory: false, revision: 1, size: 19)]
                    try save(entries)
                    try Data("Hello from SUIZAI.\n".utf8).write(to: contentURL("file-welcome"), options: .atomic)
                }
            }
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    private func load() throws -> [MockEntry] { try JSONDecoder().decode([MockEntry].self, from: Data(contentsOf: catalogURL)) }
    private func save(_ entries: [MockEntry]) throws { try JSONEncoder().encode(entries).write(to: catalogURL, options: .atomic) }
    private func contentURL(_ id: String) -> URL { contentDirectory.appendingPathComponent(id) }

    func item(_ id: String) throws -> MockEntry? { try locked { try load().first { $0.id == id } } }
    func children(of id: String) throws -> [MockEntry] { try locked { try load().filter { $0.parentID == id }.sorted { $0.name < $1.name } } }
    func allItems() throws -> [MockEntry] { try locked { try load() } }

    @discardableResult func create(parentID: String, name: String, isDirectory: Bool, contents: Data = Data()) throws -> MockEntry {
        try locked {
            var entries = try load()
            guard parentID == Self.rootID || entries.contains(where: { $0.id == parentID && $0.isDirectory }) else { throw MockStoreError.notDirectory }
            guard valid(name) else { throw MockStoreError.invalidName }
            guard !entries.contains(where: { $0.parentID == parentID && $0.name == name }) else { throw MockStoreError.duplicateName }
            let entry = MockEntry(id: UUID().uuidString, parentID: parentID, name: name, isDirectory: isDirectory, revision: 1, size: isDirectory ? 0 : contents.count)
            if !isDirectory { try contents.write(to: contentURL(entry.id), options: .atomic) }
            entries.append(entry)
            try save(entries)
            return entry
        }
    }

    @discardableResult func modify(id: String, parentID: String, name: String, contents: Data?) throws -> MockEntry {
        try locked {
            var entries = try load()
            guard let index = entries.firstIndex(where: { $0.id == id }) else { throw MockStoreError.notFound }
            guard parentID == Self.rootID || entries.contains(where: { $0.id == parentID && $0.isDirectory }) else { throw MockStoreError.notDirectory }
            guard valid(name) else { throw MockStoreError.invalidName }
            guard !entries.contains(where: { $0.id != id && $0.parentID == parentID && $0.name == name }) else { throw MockStoreError.duplicateName }
            if entries[index].isDirectory && contents != nil { throw MockStoreError.notDirectory }
            // A directory cannot be moved beneath itself.
            var ancestor = parentID
            while ancestor != Self.rootID {
                if ancestor == id { throw MockStoreError.invalidName }
                guard let parent = entries.first(where: { $0.id == ancestor }) else { throw MockStoreError.notFound }
                ancestor = parent.parentID
            }
            if let contents { try contents.write(to: contentURL(id), options: .atomic); entries[index].size = contents.count }
            entries[index].parentID = parentID
            entries[index].name = name
            entries[index].revision += 1
            try save(entries)
            return entries[index]
        }
    }

    func delete(id: String) throws {
        try locked {
            var entries = try load()
            guard let entry = entries.first(where: { $0.id == id }) else { throw MockStoreError.notFound }
            guard !entries.contains(where: { $0.parentID == id }) else { throw MockStoreError.nonEmptyDirectory }
            entries.removeAll { $0.id == id }
            try save(entries)
            if !entry.isDirectory { try? FileManager.default.removeItem(at: contentURL(id)) }
        }
    }

    func materialize(id: String, into url: URL) throws {
        try locked {
            guard let entry = try load().first(where: { $0.id == id }), !entry.isDirectory else { throw MockStoreError.notFound }
            try FileManager.default.copyItem(at: contentURL(id), to: url)
        }
    }

    private func valid(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }
}
