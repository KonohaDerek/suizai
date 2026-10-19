import SwiftUI
import FileProvider

@main struct SuizaiApp: App {
    @AppStorage("rustFixtureEnabled", store: UserDefaults(suiteName: FixtureSettings.group)) private var rustEnabled = false
    @AppStorage("rustFixtureLocale", store: UserDefaults(suiteName: FixtureSettings.group)) private var rustLocale = "zh-TW"
    @AppStorage("rustFixtureDelayMS", store: UserDefaults(suiteName: FixtureSettings.group)) private var rustDelay = 0
    @State private var message = ""
    @State private var installed = false
    private let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("suizai.mock"), displayName: "SUIZAI Mock")

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("SUIZAI Phase 0").font(.title)
                Text("Local mock files only")
                Toggle(label("啟用 Rust 測試檔案", "Enable Rust test file", "Rust テストファイルを有効化"), isOn: $rustEnabled)
                Picker(label("測試檔案語言", "Test file language", "テストファイルの言語"), selection: $rustLocale) {
                    Text("繁體中文").tag("zh-TW")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                }
                .disabled(!rustEnabled)
                Stepper("\(label("測試延遲", "Test delay", "テスト遅延")): \(rustDelay) ms", value: $rustDelay, in: 0...500, step: 50)
                    .disabled(!rustEnabled)
                Text(label("在檔案 App 開啟 Books/Notes/SUIZAI-Rust.txt。修改設定後重新開啟檔案。", "Open Books/Notes/SUIZAI-Rust.txt in Files. Reopen it after changing settings.", "ファイル App で Books/Notes/SUIZAI-Rust.txt を開いてください。設定変更後は開き直してください。"))
                    .font(.footnote)
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
            .onChange(of: rustEnabled) { signalFixtureChange() }
            .onChange(of: rustLocale) { signalFixtureChange() }
        }
    }

    private func refresh() {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
            Task { @MainActor in installed = domains.contains { $0.identifier == domain.identifier } }
        }
    }

    private func label(_ zh: String, _ en: String, _ ja: String) -> String {
        switch rustLocale { case "en": return en; case "ja": return ja; default: return zh }
    }

    private func signalFixtureChange() {
        guard let manager = NSFileProviderManager(for: domain) else { return }
        manager.signalEnumerator(for: NSFileProviderItemIdentifier("folder-notes")) { _ in }
        manager.signalEnumerator(for: .workingSet) { _ in }
    }
}
