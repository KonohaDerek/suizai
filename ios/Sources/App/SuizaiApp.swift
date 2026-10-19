import SwiftUI
import FileProvider

@main struct SuizaiApp: App {
    @State private var message = ""
    @State private var installed = false
    private let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("suizai.mock"), displayName: "SUIZAI Mock")

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("SUIZAI Phase 0").font(.title)
                Text("Local mock files only")
                Button(installed ? "Remove Mock Domain" : "Add Mock Domain") {
                    if installed {
                        NSFileProviderManager.remove(domain) { error in
                            Task { @MainActor in message = error?.localizedDescription ?? "Domain removed"; refresh() }
                        }
                    } else {
                        do {
                            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.suizai.phase0") else { throw CocoaError(.fileNoSuchFile) }
                            _ = try MockStore(directory: container.appendingPathComponent("MockProvider", isDirectory: true))
                            NSFileProviderManager.add(domain) { error in
                                Task { @MainActor in message = error?.localizedDescription ?? "Domain added"; refresh() }
                            }
                        } catch { message = error.localizedDescription }
                    }
                }
                Text(message).font(.footnote)
            }
            .padding()
            .task { refresh() }
        }
    }

    private func refresh() {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
            Task { @MainActor in installed = domains.contains { $0.identifier == domain.identifier } }
        }
    }
}
