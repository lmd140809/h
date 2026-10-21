import SwiftUI
import UIKit

// MARK: - View

struct AppDataBrowserView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model = AppDataBrowserModel()
    @State private var searchText = ""
    @State private var workspaceURL: URL?
    @Binding private var tabSession: FilesTabSession

    init(tabSession: Binding<FilesTabSession>) {
        _tabSession = tabSession
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }

    private func filteredApps() -> [InstalledApp] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return model.apps }
        return model.apps.filter {
            $0.displayName.localizedStandardContains(q)
                || $0.name.localizedStandardContains(q)
                || $0.bundleID.localizedStandardContains(q)
        }
    }

    private func overlayState(filteredCount: Int) -> AppBrowserOverlayState {
        if (model.isLoading || model.isResolving) && model.apps.isEmpty { return .loading }
        if model.apps.isEmpty { return .empty }
        if filteredCount == 0 { return .noResults }
        return .none
    }

    var body: some View {
        NavigationStack(path: activeNavigationPath) {
            appList
                .navigationTitle(language.text("browser.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        FilesTabToolbarButton(session: $tabSession)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { model.reload() } label: {
                            if model.isResolving {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(model.isResolving)
                        .accessibilityLabel(language.text("browser.retry"))
                    }
                }
                .task {
                    if workspaceURL == nil {
                        workspaceURL = try? PatchWorkspaceService.documentsRootURL()
                        _ = try? PatchWorkspaceService.patchesRootURL()
                    }
                    model.loadIfNeeded()
                }
                .navigationDestination(for: FileBrowserDestination.self) { destination in
                    if destination.startPath == destination.containerPath {
                        FileBrowserView(
                            containerPath: destination.containerPath,
                            title: destination.title,
                            bundleID: destination.bundleID,
                            filesTabSession: $tabSession
                        )
                    } else {
                        FileBrowserView(
                            containerPath: destination.containerPath,
                            startPath: destination.startPath,
                            title: destination.title,
                            bundleID: destination.bundleID,
                            filesTabSession: $tabSession
                        )
                    }
                }
        }
    }

    private var activeNavigationPath: Binding<[FileBrowserDestination]> {
        Binding(
            get: { tabSession.activeTab?.navigationPath ?? [] },
            set: { tabSession.setActiveNavigationPath($0) }
        )
    }

    private var appList: some View {
        VStack(spacing: 0) {
            if horizontalSizeClass == .regular {
                FilesTabStrip(session: $tabSession)
            }
            AppSearchField(
                text: $searchText,
                prompt: language.text("browser.search"),
                clearLabel: language.text("common.clear")
            )
            Divider()
            appRows
        }
    }

    private var appRows: some View {
        let apps = filteredApps()          // chỉ tính một lần mỗi lần render
        let state = overlayState(filteredCount: apps.count)

        return List {
            if let workspaceURL {
                Section(language.text("browser.workspace")) {
                    let destination = FileBrowserDestination(
                        containerPath: workspaceURL.path,
                        startPath: workspaceURL.path,
                        title: "OGIOS",
                        bundleID: nil
                    )
                    NavigationLink(value: destination) {
                        HStack(spacing: 10) {
                            AppRowIcon(systemName: "folder.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OGIOS")
                                    .font(.subheadline.weight(.semibold))
                                Text(language.text("browser.workspace_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .contextMenu { openInNewTabButton(destination) }
                }
            }

            Section {
                ForEach(apps) { app in
                    if app.containerPath.isEmpty {
                        appRow(app)
                            .contextMenu { copyBundleIDButton(app) }
                    } else {
                        let destination = FileBrowserDestination(
                            containerPath: app.containerPath,
                            startPath: app.containerPath,
                            title: app.displayName,
                            bundleID: app.bundleID
                        )
                        NavigationLink(value: destination) {
                            appRow(app)
                        }
                        .contextMenu {
                            openInNewTabButton(destination)
                            copyBundleIDButton(app)
                        }
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Text(language.text("browser.apps_count", Int64(apps.count)))
                    Spacer()
                    if model.isResolving {
                        ProgressView().controlSize(.mini)
                        Text(language.text("browser.mha_scanning"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 48)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await model.reloadAndWait() }
        .overlay {
            Group {
                switch state {
                case .loading:
                    ProgressView(language.text("browser.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:     emptyView
                case .noResults: searchEmptyView
                case .none:      EmptyView()
                }
            }
            .transition(.opacity)
            .animation(interfaceAnimation, value: state)
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            BrowserAppIcon(app: app)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if !app.version.isEmpty {
                Text(app.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
        .accessibilityElement(children: .combine)
    }

    private func openInNewTabButton(_ destination: FileBrowserDestination) -> some View {
        Button {
            tabSession.openTab(navigationPath: [destination])
        } label: {
            Label(language.text("browser.open_new_tab"), systemImage: "square.on.square")
        }
    }

    // Cần thêm key "browser.copy_bundle_id" vào file ngôn ngữ
    private func copyBundleIDButton(_ app: InstalledApp) -> some View {
        Button {
            UIPasteboard.general.string = app.bundleID
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            Label(language.text("browser.copy_bundle_id"), systemImage: "doc.on.doc")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("browser.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Button(language.text("browser.retry")) { model.reload() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var searchEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("browser.search_empty"))
                .font(.subheadline.weight(.medium))
            Text(language.text("browser.search_apps_empty_message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private enum AppBrowserOverlayState: Equatable {
    case loading, empty, noResults, none
}

// MARK: - Model

@MainActor
final class AppDataBrowserModel: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isResolving = false

    private var workTask: Task<Void, Never>?
    private var generation = 0      // mỗi lần reload tăng 1 → kết quả của lần cũ bị bỏ
    private var lastSeq = 0         // chỉ nhận bản cập nhật tiến độ mới hơn
    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reloadAndWait() async {
        reload()
        await workTask?.value
    }

    func reload() {
        workTask?.cancel()
        generation += 1
        lastSeq = 0
        let token = generation
        isLoading = true
        isResolving = true

        workTask = Task.detached(priority: .userInitiated) { [weak self] in
            let counter = SequenceCounter()
            let result = Self.discover { partial in
                guard !Task.isCancelled else { return }
                let seq = counter.next()
                Task { @MainActor [weak self] in
                    self?.applyPartial(partial, token: token, seq: seq)
                }
            }
            guard !Task.isCancelled else { return }
            await self?.finish(result, token: token)
        }
    }

    private func applyPartial(_ partial: [InstalledApp], token: Int, seq: Int) {
        guard token == generation, seq > lastSeq else { return }
        lastSeq = seq
        apps = partial
        isLoading = false
    }

    private func finish(_ result: [InstalledApp], token: Int) {
        guard token == generation else { return }
        lastSeq = .max                 // chặn mọi bản tiến độ đến muộn
        apps = result
        isLoading = false
        isResolving = false
    }

    // MARK: Discovery (chạy nền, không đụng vào state)

    private nonisolated static func visibleSorted(_ apps: [InstalledApp]) -> [InstalledApp] {
        apps
            .filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private nonisolated static func discover(
        progress: @escaping @Sendable ([InstalledApp]) -> Void
    ) -> [InstalledApp] {
        let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
        let apiApps = ContainerStore.applyingBundleMetadata(
            to: ContainerStore.installedAppsFromAPI(),
            catalog: bundleMetadata
        )
        if apiApps.isEmpty {
            log("browser: installed-app API unavailable; trying MCM class-2 enumeration...")
        }

        let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
        let mcmApps = ContainerStore.installedAppsFromMCM(
            identifiers: dynamicIdentifiers,
            bundleMetadata: bundleMetadata
        )
        let filesystemApps = ContainerStore.containersFromFilesystem()
        let baseIdentifiedApps = mcmApps + apiApps

        let preliminary = ContainerDiscoveryMerger.merge(
            enumerated: filesystemApps,
            identified: baseIdentifiedApps,
            path: { $0.containerPath }
        )
        log("browser: merged api=\(apiApps.count), MCM=\(mcmApps.count), filesystem=\(filesystemApps.count) -> \(preliminary.count)")
        progress(visibleSorted(preliminary))

        guard !Task.isCancelled else { return [] }

        let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
        let mhaIdentifiers = MHAIdentifierCatalog.identifiers(
            dynamic: dynamicIdentifiers,
            installed: apiApps.map(\.bundleID),
            research: ContainerStore.researchAppIdentifiers,
            custom: bundleMetadata.keys.sorted(),
            launchServices: launchServicesIdentifiers
        )
        log(
            "browser: MHA catalog dynamic=\(dynamicIdentifiers.count), " +
            "installed=\(apiApps.count), research=\(ContainerStore.researchAppIdentifiers.count), " +
            "LaunchServices=\(launchServicesIdentifiers.count) -> \(mhaIdentifiers.count) candidates"
        )

        let mhaApps = ContainerStore.installedAppsFromMHACandidates(
            identifiers: mhaIdentifiers,
            bundleMetadata: bundleMetadata
        ) { discovered in
            guard !Task.isCancelled else { return }
            let merged = AppDataCatalogMerger.merge(
                identified: discovered + baseIdentifiedApps,
                fallback: [],
                identifier: { $0.bundleID },
                path: { $0.containerPath }
            )
            progress(visibleSorted(merged))
        }

        guard !Task.isCancelled else { return [] }

        let allKnownApps = mhaApps + baseIdentifiedApps
        let identifiedPaths = Set(allKnownApps.map {
            ContainerDiscoveryMerger.canonicalPath($0.containerPath)
        })
        let unmatched = filesystemApps.filter {
            !identifiedPaths.contains(ContainerDiscoveryMerger.canonicalPath($0.containerPath))
        }
        let inferred = ContainerStore.inferUnidentifiedApps(
            in: unmatched,
            knownApps: allKnownApps,
            launchServicesIdentifiers: Set(launchServicesIdentifiers)
        ).filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) }

        let merged = AppDataCatalogMerger.merge(
            identified: allKnownApps,
            fallback: inferred,
            identifier: { $0.bundleID },
            path: { $0.containerPath }
        )
        return visibleSorted(merged)
    }
}

private final class SequenceCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}

// MARK: - Icon

actor AppIconLoader {
    static let shared = AppIconLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    func icon(for bundleID: String) async -> UIImage? {
        if let cached = cache.object(forKey: bundleID as NSString) { return cached }
        if let task = inflight[bundleID] { return await task.value }   // gộp request trùng

        // Khai báo kiểu trả về UIImage? để khớp dictionary,
        // dù iconForBundleID trả UIImage hay UIImage?
        let task = Task.detached(priority: .utility) { () -> UIImage? in
            iconForBundleID(bundleID)
        }
        inflight[bundleID] = task
        let image = await task.value
        inflight[bundleID] = nil

        if let image {
            cache.setObject(image, forKey: bundleID as NSString)
        }
        return image
    }
}

struct BrowserAppIcon: View {
    let app: InstalledApp
    @State private var resolvedIcon: UIImage?

    init(app: InstalledApp) {
        self.app = app
        _resolvedIcon = State(initialValue: app.icon)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(uiImage: resolvedIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app")
                    .font(.system(size: AppTheme.rowIconSize, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: AppTheme.appIconSize, height: AppTheme.appIconSize)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
        .task(id: app.bundleID) {
            guard resolvedIcon == nil else { return }
            resolvedIcon = await AppIconLoader.shared.icon(for: app.bundleID)
        }
    }
}
