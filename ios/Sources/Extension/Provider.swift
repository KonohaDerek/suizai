import FileProvider
import UniformTypeIdentifiers

private enum ProviderFiles {
    static let group = "group.dev.suizai.phase0"
    static func store() throws -> MockStore {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { throw CocoaError(.fileNoSuchFile) }
        return try MockStore(directory: container.appendingPathComponent("MockProvider", isDirectory: true))
    }
    static func error(_ error: Error) -> Error {
        switch error {
        case MockStoreError.notFound: return NSFileProviderError(.noSuchItem)
        case MockStoreError.duplicateName: return NSFileProviderError(.filenameCollision)
        case MockStoreError.invalidAnchor: return NSFileProviderError(.syncAnchorExpired)
        case MockStoreError.nonEmptyDirectory: return NSFileProviderError(.directoryNotEmpty)
        case MockStoreError.invalidName, MockStoreError.notDirectory: return CocoaError(.fileWriteInvalidFileName)
        default: return error
        }
    }
    static func externalID(_ id: String) -> NSFileProviderItemIdentifier {
        id == MockStore.rootID ? .rootContainer : NSFileProviderItemIdentifier(id)
    }
    static func internalID(_ id: NSFileProviderItemIdentifier) -> String {
        if id == .rootContainer { return MockStore.rootID }
        if id == .workingSet { return "working-set" }
        return id.rawValue
    }
    static func anchor(_ sequence: Int) -> NSFileProviderSyncAnchor { NSFileProviderSyncAnchor(Data(String(sequence).utf8)) }
    static func sequence(_ anchor: NSFileProviderSyncAnchor) throws -> Int {
        guard let value = Int(String(decoding: anchor.rawValue, as: UTF8.self)) else { throw MockStoreError.invalidAnchor }
        return value
    }
    static func mutationError(_ error: Error, parentID: String, name: String) -> Error {
        if case MockStoreError.duplicateName = error,
           let existing = try? store().item(parentID: parentID, name: name) {
            return NSError.fileProviderErrorForCollision(with: ProviderItem(existing))
        }
        return self.error(error)
    }
}

final class ProviderItem: NSObject, NSFileProviderItem {
    let entry: MockEntry?
    init(_ entry: MockEntry?) { self.entry = entry }
    var itemIdentifier: NSFileProviderItemIdentifier { ProviderFiles.externalID(entry?.id ?? MockStore.rootID) }
    var parentItemIdentifier: NSFileProviderItemIdentifier { ProviderFiles.externalID(entry?.parentID ?? MockStore.rootID) }
    var filename: String { entry?.name ?? "SUIZAI Mock" }
    var contentType: UTType { entry?.isDirectory == false ? .plainText : .folder }
    var capabilities: NSFileProviderItemCapabilities {
        entry?.isDirectory == false ? [.allowsReading, .allowsWriting, .allowsReparenting, .allowsRenaming, .allowsDeleting]
            : [.allowsReading, .allowsReparenting, .allowsRenaming, .allowsDeleting, .allowsAddingSubItems]
    }
    var documentSize: NSNumber? { NSNumber(value: entry?.size ?? 0) }
    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data(String(entry?.contentRevision ?? 1).utf8),
                                         metadataVersion: Data(String(entry?.revision ?? 1).utf8))
    }
}

final class ProviderEnumerator: NSObject, NSFileProviderEnumerator {
    let containerID: String
    init(_ containerID: String) { self.containerID = containerID }
    func invalidate() {}
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            let store = try ProviderFiles.store()
            let entries = containerID == "working-set" ? try store.allItems() : try store.children(of: containerID)
            observer.didEnumerate(entries.map(ProviderItem.init))
            observer.finishEnumerating(upTo: nil)
        } catch { observer.finishEnumeratingWithError(ProviderFiles.error(error)) }
    }
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        do {
            let changes = try ProviderFiles.store().changes(after: ProviderFiles.sequence(anchor), in: containerID)
            if !changes.updates.isEmpty { observer.didUpdate(changes.updates.map(ProviderItem.init)) }
            if !changes.deletions.isEmpty { observer.didDeleteItems(withIdentifiers: changes.deletions.map { NSFileProviderItemIdentifier($0) }) }
            observer.finishEnumeratingChanges(upTo: ProviderFiles.anchor(changes.anchor), moreComing: false)
        } catch { observer.finishEnumeratingWithError(ProviderFiles.error(error)) }
    }
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(try? ProviderFiles.anchor(ProviderFiles.store().currentAnchor()))
    }
}

final class Provider: NSObject, NSFileProviderReplicatedExtension {
    let domain: NSFileProviderDomain
    required init(domain: NSFileProviderDomain) { self.domain = domain; super.init() }
    func invalidate() {}
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        do {
            if identifier == .rootContainer { completionHandler(ProviderItem(nil), nil) }
            else if let item = try ProviderFiles.store().item(identifier.rawValue) { completionHandler(ProviderItem(item), nil) }
            else { completionHandler(nil, NSFileProviderError(.noSuchItem)) }
        } catch { completionHandler(nil, ProviderFiles.error(error)) }
        return Progress(totalUnitCount: 1)
    }
    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        ProviderEnumerator(ProviderFiles.internalID(containerItemIdentifier))
    }
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        do {
            let store = try ProviderFiles.store()
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let entry = try store.materialize(id: itemIdentifier.rawValue, into: destination)
            completionHandler(destination, ProviderItem(entry), nil)
        } catch { completionHandler(nil, nil, ProviderFiles.error(error)) }
        return Progress(totalUnitCount: 1)
    }
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        do {
            let isDirectory = itemTemplate.contentType?.conforms(to: .folder) == true
            let data = isDirectory ? Data() : try url.map { try Data(contentsOf: $0) } ?? Data()
            let entry = try ProviderFiles.store().create(parentID: ProviderFiles.internalID(itemTemplate.parentItemIdentifier), name: itemTemplate.filename, isDirectory: isDirectory, contents: data)
            completionHandler(ProviderItem(entry), [], false, nil)
            signal(entry.parentID)
        } catch { completionHandler(nil, [], false, ProviderFiles.mutationError(error, parentID: ProviderFiles.internalID(itemTemplate.parentItemIdentifier), name: itemTemplate.filename)) }
        return Progress(totalUnitCount: 1)
    }
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        do {
            let store = try ProviderFiles.store()
            let data = try newContents.map { try Data(contentsOf: $0) }
            let (entry, oldParentID) = try store.modify(id: item.itemIdentifier.rawValue, parentID: ProviderFiles.internalID(item.parentItemIdentifier), name: item.filename, contents: data)
            completionHandler(ProviderItem(entry), [], false, nil)
            signal(oldParentID)
            signal(entry.parentID)
        } catch { completionHandler(nil, [], false, ProviderFiles.mutationError(error, parentID: ProviderFiles.internalID(item.parentItemIdentifier), name: item.filename)) }
        return Progress(totalUnitCount: 1)
    }
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        do {
            let store = try ProviderFiles.store()
            let old = try store.delete(id: identifier.rawValue)
            completionHandler(nil)
            signal(old.parentID)
        } catch { completionHandler(ProviderFiles.error(error)) }
        return Progress(totalUnitCount: 1)
    }
    private func signal(_ parentID: String) {
        NSFileProviderManager(for: domain)?.signalEnumerator(for: ProviderFiles.externalID(parentID)) { _ in }
        NSFileProviderManager(for: domain)?.signalEnumerator(for: .workingSet) { _ in }
    }
}
