import SwiftUI

struct PatchTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var updateManager = PatchUpdateManager.shared

    @State private var patchOperationBusy = false
    @State private var status = StatusMessage(text: "READY — SELECT A PATCH", kind: .info)
    @State private var showCleaner = false
    @State private var showUpdateSheet = false
    @State private var showDisableAllAlert = false
    @State private var patchStates: [String: Bool] = [:]

    // MARK: - Status model

    private enum StatusKind {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info:    return .green
            case .success: return .green
            case .warning: return .yellow
            case .error:   return .red
            }
        }
        var icon: String {
            switch self {
            case .info:    return "circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "lock.fill"
            case .error:   return "exclamationmark.triangle.fill"
            }
        }
    }

    private struct StatusMessage {
        let text: String
        let kind: StatusKind
        var date = Date()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // MARK: - Derived

    private var sortedItems: [PatchLibraryItem] {
        patchStore.items.sorted { $0.packageURL.lastPathComponent < $1.packageURL.lastPathComponent }
    }

    private var activeCount: Int { patchStates.values.filter { $0 }.count }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if !updateManager.availableUpdates.isEmpty { updateBanner }

                summaryHeader

                if sortedItems.isEmpty {
                    emptyState
                } else {
                    patchGrid
                }

                statusBar
                launchGameButton
                cleanerButton
                if activeCount > 0 { disableAllButton }
            }
            .padding(18)
        }
        .sheet(isPresented: $showCleaner) { CleanerView() }
        .sheet(isPresented: $showUpdateSheet) { PatchUpdateSheet(manager: updateManager) }
        .alert("Tắt tất cả patch?", isPresented: $showDisableAllAlert) {
            Button("Huỷ", role: .cancel) { }
            Button("Tắt tất cả", role: .destructive) { disableAll() }
        } message: {
            Text("Các patch đang bật sẽ được khôi phục về file gốc.")
        }
        .onAppear {
            syncPatchStates()
            Task { _ = await updateManager.checkForUpdates() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, !patchOperationBusy { syncPatchStates() }
        }
        .onChange(of: patchStore.items.count) { _ in
            if !patchOperationBusy { syncPatchStates() }
        }
    }

    // MARK: - Sections

    private var updateBanner: some View {
        Button { showUpdateSheet = true } label: {
            HStack {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading) {
                    Text("CÓ BẢN CẬP NHẬT MỚI").font(.system(size: 12, weight: .black))
                    Text("Bấm để xem chi tiết").font(.system(size: 10)).opacity(0.7)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).opacity(0.5)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.blue.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var summaryHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: activeCount > 0 ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(activeCount > 0 ? ProTheme.gold : .white.opacity(0.4))

            Text("\(activeCount)/\(sortedItems.count) ĐANG BẬT")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Button { syncPatchStates(); setStatus("Đã làm mới trạng thái", .info) } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(patchOperationBusy)
            .accessibilityLabel("Làm mới trạng thái")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5), in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
            Text("Chưa có patch nào")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text("Kiểm tra bản cập nhật hoặc thêm patch trong Patch Projects.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }

    private var patchGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(sortedItems, id: \.id) { item in
                patchCardView(for: item)
            }
        }
    }

    private func patchCardView(for item: PatchLibraryItem) -> some View {
        let filename = item.packageURL.lastPathComponent
        let savedName = UserDefaults.standard.string(forKey: "patch_name_\(filename)")
        let displayName = savedName ?? getDefaultName(for: filename)

        return ProPatchCard(
            name: displayName,
            target: "FREE FIRE",
            color: getColorForPatch(filename),
            // Chỉ đọc: trạng thái chỉ đổi sau khi thao tác thật sự xong
            isEnabled: Binding(
                get: { patchStates[filename] ?? false },
                set: { _ in }
            ),
            isBusy: patchOperationBusy
        ) {
            togglePatch(packageFilename: filename)
        }
    }

    private var statusBar: some View {
        let kind: StatusKind = patchOperationBusy ? .info : status.kind
        let dot: Color = patchOperationBusy ? ProTheme.primary : kind.color

        return HStack(spacing: 8) {
            if patchOperationBusy {
                ProgressView().controlSize(.mini).tint(.white)
            } else {
                Image(systemName: kind.icon)
                    .font(.system(size: kind == .info ? 7 : 11, weight: .bold))
                    .foregroundStyle(dot)
            }

            Text(patchOperationBusy ? "PROCESSING..." : status.text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 6)

            if !patchOperationBusy {
                Text(Self.timeFormatter.string(from: status.date))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5), in: Capsule())
        .overlay(Capsule().stroke(dot.opacity(0.35), lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: status.text)
    }

    private var launchGameButton: some View {
        Button { launchGame() } label: {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(ProTheme.primary)
                Text("MỞ FREE FIRE").font(.system(size: 14, weight: .black))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(ProTheme.primary)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ProTheme.primary.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }

    private var cleanerButton: some View {
        Button { showCleaner = true } label: {
            HStack {
                Image(systemName: "trash.slash.fill").foregroundStyle(.orange)
                Text("DỌN CACHE & TEMP").font(.system(size: 14, weight: .black))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.orange)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(patchOperationBusy)
    }

    private var disableAllButton: some View {
        Button { showDisableAllAlert = true } label: {
            HStack {
                Image(systemName: "power").foregroundStyle(.red)
                Text("TẮT TẤT CẢ PATCH").font(.system(size: 14, weight: .black))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .disabled(patchOperationBusy)
    }

    // MARK: - Names & colors

    private func getDefaultName(for filename: String) -> String {
        if filename.contains("(20)") { return "AimBody" }
        if filename.contains("(21)") { return "AimLock" }
        if filename.contains("(22)") { return "Antiban" }
        if filename.contains("(23)") { return "Nhẹ Tâm" }
        return filename
            .replacingOccurrences(of: "OGIOS File (", with: "Patch ")
            .replacingOccurrences(of: ").OGIOS", with: "")
    }

    private func getColorForPatch(_ filename: String) -> Color {
        if filename.contains("(20)") { return ProTheme.primary }
        if filename.contains("(21)") { return ProTheme.gold }
        if filename.contains("(22)") { return .green }
        if filename.contains("(23)") { return .orange }
        return .cyan
    }

    // MARK: - Helpers

    private func setStatus(_ text: String, _ kind: StatusKind) {
        status = StatusMessage(text: text, kind: kind)
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func launchGame() {
        guard let url = URL(string: "freefireth://") else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            DispatchQueue.main.async {
                if !ok {
                    setStatus("Không mở được Free Fire — kiểm tra game đã cài chưa", .error)
                    haptic(.error)
                }
            }
        }
    }

    // MARK: - Trạng thái (nguồn sự thật = receipt trên máy)

    private func syncPatchStates() {
        var states: [String: Bool] = [:]
        for item in patchStore.items {
            states[item.packageURL.lastPathComponent] =
                DevicePatchService.latestReceipt(projectID: item.id) != nil
        }
        patchStates = states
    }

    private enum PatchActionResult {
        case applied
        case restored
        case needsPassword
        case failed(String)
    }

    private func togglePatch(packageFilename: String) {
        guard !patchOperationBusy else { return }
        guard let item = patchStore.items.first(where: {
            $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame
        }) else { return }

        patchOperationBusy = true
        let project = item.project
        let projectID = item.id

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult

            // Quyết định dựa trên receipt thật, KHÔNG dựa vào giao diện
            if let receipt = DevicePatchService.latestReceipt(projectID: projectID) {
                do {
                    try DevicePatchService.restore(receipt: receipt)
                    result = .restored
                } catch {
                    result = .failed("RESTORE FAILED — \(error.localizedDescription)")
                }
            } else if let project {
                do {
                    _ = try DevicePatchService.apply(project: project)
                    result = .applied
                } catch {
                    result = .failed("APPLY FAILED — \(error.localizedDescription)")
                }
            } else {
                result = .needsPassword
            }

            let isActiveNow = DevicePatchService.latestReceipt(projectID: projectID) != nil

            DispatchQueue.main.async {
                patchStates[packageFilename] = isActiveNow

                switch result {
                case .applied:
                    setStatus("Inject Successful — \(packageFilename)", .success)
                    haptic(.success)
                case .restored:
                    setStatus("Restore Successful — \(packageFilename)", .success)
                    haptic(.success)
                case .needsPassword:
                    patchStore.requestUnlock(for: item)
                    setStatus("PASSWORD REQUIRED", .warning)
                    haptic(.warning)
                case .failed(let message):
                    setStatus(message, .error)
                    haptic(.error)
                }
                patchOperationBusy = false
            }
        }
    }

    private func disableAll() {
        guard !patchOperationBusy else { return }

        let targets: [(filename: String, id: PatchLibraryItem.ID)] = patchStore.items.map {
            ($0.packageURL.lastPathComponent, $0.id)
        }

        patchOperationBusy = true

        DispatchQueue.global(qos: .userInitiated).async {
            var restored = 0
            var failed = 0

            for target in targets {
                guard let receipt = DevicePatchService.latestReceipt(projectID: target.id) else { continue }
                do {
                    try DevicePatchService.restore(receipt: receipt)
                    restored += 1
                } catch {
                    failed += 1
                }
            }

            var states: [String: Bool] = [:]
            for target in targets {
                states[target.filename] = DevicePatchService.latestReceipt(projectID: target.id) != nil
            }

            DispatchQueue.main.async {
                patchStates = states
                if failed == 0 {
                    setStatus("Đã tắt \(restored) patch", .success)
                    haptic(.success)
                } else {
                    setStatus("Tắt \(restored) patch, \(failed) lỗi — thử lại từng patch", .error)
                    haptic(.error)
                }
                patchOperationBusy = false
            }
        }
    }
}
