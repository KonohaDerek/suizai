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
                Text(label("僅使用本機測試檔案", "Local mock files only", "ローカルのテストファイルのみ"))
                Toggle(label("啟用 Rust 測試檔案", "Enable Rust test file", "Rust テストファイルを有効化"), isOn: $rustEnabled)
                Picker(label("測試檔案語言", "Test file language", "テストファイルの言語"), selection: $rustLocale) {
                    Text("台灣正體中文").tag("zh-TW")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                }
                .disabled(!rustEnabled)
                Stepper("\(label("測試延遲", "Test delay", "テスト遅延")): \(rustDelay) ms", value: $rustDelay, in: 0...500, step: 50)
                    .disabled(!rustEnabled)
                Text(label("在檔案 App 開啟 SUIZAI-Rust.txt。修改設定後重新開啟檔案。", "Open SUIZAI-Rust.txt in Files. Reopen it after changing settings.", "ファイル App で SUIZAI-Rust.txt を開いてください。設定変更後は開き直してください。"))
                    .font(.footnote)
                Button(installed ? label("移除 Mock Domain", "Remove Mock Domain", "Mock Domain を削除")
                                 : label("加入 Mock Domain", "Add Mock Domain", "Mock Domain を追加")) {
                    if installed {
                        NSFileProviderManager.remove(domain) { error in
                            Task { @MainActor in message = error?.localizedDescription ?? label("已移除 Mock Domain", "Domain removed", "Mock Domain を削除しました"); refresh() }
                        }
                    } else {
                        do {
                            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dev.suizai.phase0") else { throw CocoaError(.fileNoSuchFile) }
                            _ = try MockStore(directory: container.appendingPathComponent("MockProvider", isDirectory: true))
                            NSFileProviderManager.add(domain) { error in
                                Task { @MainActor in message = error?.localizedDescription ?? label("已加入 Mock Domain", "Domain added", "Mock Domain を追加しました"); refresh() }
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
        if rustEnabled {
            do {
                guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FixtureSettings.group) else { throw CocoaError(.fileNoSuchFile) }
                let store = try MockStore(directory: container.appendingPathComponent("MockProvider", isDirectory: true))
                if try store.item(parentID: MockStore.rootID, name: FixtureSettings.filename) != nil {
                    rustEnabled = false
                    message = label("根目錄已有同名檔案；請先重新命名再啟用測試。", "A root file has this name. Rename it before enabling the test.", "ルートに同名ファイルがあります。名前を変更してからテストを有効にしてください。")
                    return
                }
            } catch { rustEnabled = false; message = error.localizedDescription; return }
        }
        guard let manager = NSFileProviderManager(for: domain) else { return }
        manager.signalEnumerator(for: .rootContainer) { _ in }
        manager.signalEnumerator(for: .workingSet) { _ in }
        manager.signalEnumerator(for: NSFileProviderItemIdentifier(FixtureSettings.id)) { _ in }
    }
}
