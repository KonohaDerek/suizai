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
    static var fixtureState: Int { FixtureSettings.enabled ? FixtureSettings.entry(locale: FixtureSettings.locale).contentRevision : 0 }
    static func anchor(_ sequence: Int, fixtureState: Int = ProviderFiles.fixtureState) -> NSFileProviderSyncAnchor {
        NSFileProviderSyncAnchor(Data("\(sequence)|\(fixtureState)".utf8))
    }
    static func sequence(_ anchor: NSFileProviderSyncAnchor) throws -> Int {
        let parts = String(decoding: anchor.rawValue, as: UTF8.self).split(separator: "|", omittingEmptySubsequences: false)
        guard (parts.count == 1 || parts.count == 2), let first = parts.first, let value = Int(first),
              (parts.count == 1 || Int(parts[1]) != nil) else { throw MockStoreError.invalidAnchor }
        return value
    }
    static func fixtureState(_ anchor: NSFileProviderSyncAnchor) -> Int {
        let parts = String(decoding: anchor.rawValue, as: UTF8.self).split(separator: "|", omittingEmptySubsequences: false)
        return parts.count == 2 ? Int(parts[1]) ?? 0 : 0 // Pre-bridge anchors were plain sequence numbers.
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
        if entry?.id == FixtureSettings.id { return [.allowsReading] }
        return entry?.isDirectory == false ? [.allowsReading, .allowsWriting, .allowsReparenting, .allowsRenaming, .allowsDeleting]
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
            let entries: [MockEntry]
            if containerID == "working-set" { entries = try store.allItems() }
            else if let item = try store.item(containerID), !item.isDirectory { entries = [item] }
            else { entries = try store.children(of: containerID) }
            var visible = entries
            if FixtureSettings.enabled && (containerID == "folder-notes" || containerID == "working-set") {
                visible.append(FixtureSettings.entry(locale: FixtureSettings.locale))
            }
            observer.didEnumerate(visible.map { ProviderItem($0) })
            observer.finishEnumerating(upTo: nil)
        } catch { observer.finishEnumeratingWithError(ProviderFiles.error(error)) }
    }
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        do {
            let changes = try ProviderFiles.store().changes(after: ProviderFiles.sequence(anchor), in: containerID)
            var updates = changes.updates
            var deletions = changes.deletions
            let fixture = FixtureSettings.enabled ? FixtureSettings.entry(locale: FixtureSettings.locale) : nil
            let currentFixtureState = fixture?.contentRevision ?? 0
            if (containerID == "folder-notes" || containerID == "working-set") &&
                ProviderFiles.fixtureState(anchor) != currentFixtureState {
                if let fixture { updates.append(fixture) }
                else { deletions.append(FixtureSettings.id) }
            }
            if !updates.isEmpty { observer.didUpdate(updates.map { ProviderItem($0) }) }
            if !deletions.isEmpty { observer.didDeleteItems(withIdentifiers: deletions.map { NSFileProviderItemIdentifier($0) }) }
            observer.finishEnumeratingChanges(upTo: ProviderFiles.anchor(changes.anchor, fixtureState: currentFixtureState), moreComing: false)
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
            else if FixtureSettings.enabled && identifier.rawValue == FixtureSettings.id { completionHandler(ProviderItem(FixtureSettings.entry(locale: FixtureSettings.locale)), nil) }
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
            let locale = FixtureSettings.locale
            return FixtureFetch.start(store: store, id: itemIdentifier.rawValue, destination: destination,
                                      enabled: FixtureSettings.enabled, locale: locale,
                                      delay: FixtureSettings.delay) { url, entry, error in
                completionHandler(url, entry.map { ProviderItem($0) }, error.map(ProviderFiles.error))
            }
        } catch {
            completionHandler(nil, nil, ProviderFiles.error(error))
            return Progress(totalUnitCount: 1)
        }
    }
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        do {
            let isDirectory = itemTemplate.contentType?.conforms(to: .folder) == true
            let data = isDirectory ? Data() : try url.map { try Data(contentsOf: $0) } ?? Data()
            let entry = try ProviderFiles.store().create(parentID: ProviderFiles.internalID(itemTemplate.parentItemIdentifier), name: itemTemplate.filename, isDirectory: isDirectory, contents: data)
            completionHandler(ProviderItem(entry), [], false, nil)
            signal([entry.parentID, entry.id])
        } catch { completionHandler(nil, [], false, ProviderFiles.mutationError(error, parentID: ProviderFiles.internalID(itemTemplate.parentItemIdentifier), name: itemTemplate.filename)) }
        return Progress(totalUnitCount: 1)
    }
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        do {
            let store = try ProviderFiles.store()
            let data = try newContents.map { try Data(contentsOf: $0) }
            let (entry, oldParentID) = try store.modify(id: item.itemIdentifier.rawValue, parentID: ProviderFiles.internalID(item.parentItemIdentifier), name: item.filename, contents: data)
            completionHandler(ProviderItem(entry), [], false, nil)
            signal([oldParentID, entry.parentID, entry.id])
        } catch { completionHandler(nil, [], false, ProviderFiles.mutationError(error, parentID: ProviderFiles.internalID(item.parentItemIdentifier), name: item.filename)) }
        return Progress(totalUnitCount: 1)
    }
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions, request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        do {
            let store = try ProviderFiles.store()
            let old = try store.delete(id: identifier.rawValue)
            completionHandler(nil)
            signal([old.parentID, old.id])
        } catch { completionHandler(ProviderFiles.error(error)) }
        return Progress(totalUnitCount: 1)
    }
    private func signal(_ ids: [String]) {
        guard let manager = NSFileProviderManager(for: domain) else { return }
        for id in Set(ids) { manager.signalEnumerator(for: ProviderFiles.externalID(id)) { _ in } }
        manager.signalEnumerator(for: .workingSet) { _ in }
    }
}
