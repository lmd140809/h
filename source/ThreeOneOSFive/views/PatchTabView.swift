import SwiftUI

struct PatchTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var updateManager = PatchUpdateManager.shared

    @State private var patchOperationBusy = false
    @State private var patchMessage = "READY — SELECT A PATCH"
    @State private var showCleaner = false
    @State private var showUpdateSheet = false
    @State private var patchStates: [String: Bool] = [:]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Banner cập nhật (nếu có)
                if !updateManager.availableUpdates.isEmpty {
                    Button { showUpdateSheet = true } label: {
                        HStack {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.2)).frame(width: 36, height: 36)
                                Image(systemName: "arrow.down.circle.fill").font(.system(size: 18)).foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading) {
                                Text("CÓ BẢN CẬP NHẬT MỚI").font(.system(size: 12, weight: .black))
                                Text("Bấm để xem chi tiết").font(.system(size: 10)).opacity(0.7)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14)).opacity(0.5)
                        }
                        .foregroundStyle(.white).padding().background(Color.blue.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }

                // Grid Patch Tự Động
                patchGrid

                // Status Bar
                statusBar

                // Launch Game
                launchGameButton

                // Cleaner
                cleanerButton
            }
            .padding(18)
        }
        .sheet(isPresented: $showCleaner) { CleanerView() }
        .sheet(isPresented: $showUpdateSheet) { PatchUpdateSheet(manager: updateManager) }
        .onAppear {
            syncPatchStates()
            Task { _ = await updateManager.checkForUpdates() }
        }
    }

    private var patchGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            let items = patchStore.items.sorted { $0.packageURL.lastPathComponent < $1.packageURL.lastPathComponent }
            
            ForEach(items, id: \.id) { item in
                patchCardView(for: item)
            }
        }
    }

    private func patchCardView(for item: PatchLibraryItem) -> some View {
        let filename = item.packageURL.lastPathComponent
        let savedName = UserDefaults.standard.string(forKey: "patch_name_\(filename)")
        let displayName = savedName ?? getDefaultName(for: filename)
        let color = getColorForPatch(filename)
        
        return ProPatchCard(
            name: displayName,
            target: "FREE FIRE",
            color: color,
            isEnabled: Binding(
                get: { patchStates[filename] ?? false },
                set: { patchStates[filename] = $0 }
            ),
            isBusy: patchOperationBusy
        ) {
            togglePatch(packageFilename: filename)
        }
    }

    private var statusBar: some View {
        HStack {
            Circle().fill(patchOperationBusy ? ProTheme.primary : .green).frame(width: 8, height: 8)
            Text(patchOperationBusy ? "PROCESSING..." : patchMessage)
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.8))
            Spacer()
        }.padding().background(Color.black.opacity(0.5), in: Capsule())
    }

    private var launchGameButton: some View {
        Button { UIApplication.shared.open(URL(string: "freefireth://")!) } label: {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(ProTheme.primary)
                Text("MỞ FREE FIRE").font(.system(size: 14, weight: .black))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(ProTheme.primary)
            }.foregroundStyle(.white).padding().background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(ProTheme.primary.opacity(0.5)))
        }
    }

    private var cleanerButton: some View {
        Button { showCleaner = true } label: {
            HStack {
                Image(systemName: "trash.slash.fill").foregroundStyle(.orange)
                Text("DỌN CACHE & TEMP").font(.system(size: 14, weight: .black))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.orange)
            }.foregroundStyle(.white).padding().background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5)))
        }
    }

    private func getDefaultName(for filename: String) -> String {
        if filename.contains("(20)") { return "AimBody" }
        if filename.contains("(21)") { return "AimLock" }
        if filename.contains("(22)") { return "Antiban" }
        if filename.contains("(23)") { return "Nhẹ Tâm" }
        return filename.replacingOccurrences(of: "OGIOS File (", with: "Patch ").replacingOccurrences(of: ").OGIOS", with: "")
    }

    private func getColorForPatch(_ filename: String) -> Color {
        if filename.contains("(20)") { return ProTheme.primary }
        if filename.contains("(21)") { return ProTheme.gold }
        if filename.contains("(22)") { return .green }
        if filename.contains("(23)") { return .orange }
        return .cyan
    }

    private func syncPatchStates() {
        for item in patchStore.items {
            let filename = item.packageURL.lastPathComponent
            patchStates[filename] = isPatchActive(filename)
        }
    }

    private func isPatchActive(_ packageFilename: String) -> Bool {
        patchStore.items.first(where: { $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame })
            .flatMap { DevicePatchService.latestReceipt(projectID: $0.id) } != nil
    }

    private enum PatchActionResult { case applied, restored, unavailable(String) }

    private func togglePatch(packageFilename: String) {
        guard !patchOperationBusy else { return }
        guard let item = patchStore.items.first(where: { $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame }) else { return }

        let wasEnabled = patchStates[packageFilename] ?? false
        patchOperationBusy = true
        patchMessage = "PROCESSING — \(packageFilename)"
        let project = item.project
        let projectID = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult
            do {
                if wasEnabled {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                        result = .unavailable("NO ACTIVE RECEIPT")
                        DispatchQueue.main.async {
                            self.patchStates[packageFilename] = false
                            self.patchMessage = "OFF — NO ACTIVE PATCH"
                            self.patchOperationBusy = false
                        }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    result = .restored
                } else {
                    guard let project else {
                        result = .unavailable("PASSWORD REQUIRED")
                        DispatchQueue.main.async {
                            self.patchStore.requestUnlock(for: item)
                            self.patchMessage = "PASSWORD REQUIRED"
                            self.patchOperationBusy = false
                        }
                        return
                    }
                    _ = try DevicePatchService.apply(project: project)
                    result = .applied
                }
            } catch { result = .unavailable("FAILED — \(String(describing: error))") }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.patchStates[packageFilename] = true
                    self.patchMessage = "Inject Successful — \(packageFilename)"
                case .restored:
                    self.patchStates[packageFilename] = false
                    self.patchMessage = "Restore Successful — \(packageFilename)"
                case .unavailable(let message): self.patchMessage = message
                }
                self.patchOperationBusy = false
            }
        }
    }
}
