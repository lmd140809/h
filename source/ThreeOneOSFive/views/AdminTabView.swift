import SwiftUI

struct AdminTabView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showProjects = false
    @State private var showLicense = false
    @State private var showPairingAccess = false
    @State private var showDeactivateAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                profileHeader
                adminOptions
                zaloCard
                creditsSection
                proFooter
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showSettings)  { SettingsView() }
        .sheet(isPresented: $showLogs)      { LogView() }
        .sheet(isPresented: $showProjects)  { PatchProjectsView() }
        .sheet(isPresented: $showLicense)   { LicenseInfoView() }
        .sheet(isPresented: $showPairingAccess) { PairingAccessView() }
        .alert("Xoá kích hoạt?", isPresented: $showDeactivateAlert) {
            Button("Huỷ", role: .cancel) { }
            Button("Xoá", role: .destructive) {
                licenseManager.deactivate()
            }
        } message: {
            Text("Bạn sẽ cần nhập lại key để vào app.")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ProTheme.goldGradient)
                    .frame(width: 80, height: 80)
                    .blur(radius: 12)
                    .opacity(0.6)

                Circle()
                    .stroke(ProTheme.goldGradient, lineWidth: 2)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color.black.opacity(0.9))
                    .frame(width: 66, height: 66)

                Text("MD")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(ProTheme.goldGradient)
            }

            Text("Admin MinhDuc")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Developer • Patch Master")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ProTheme.gold.opacity(0.9))

            HStack(spacing: 5) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ProTheme.gold)

                Text("PREMIUM EDITION")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(ProTheme.goldGradient)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(ProTheme.gold.opacity(0.15)))
            .overlay(Capsule().stroke(ProTheme.gold.opacity(0.4), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.55))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [ProTheme.gold.opacity(0.1), .clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ProTheme.goldGradient, lineWidth: 1.3)
        )
    }

    private var adminOptions: some View {
        VStack(spacing: 10) {
            adminRow(icon: "key.fill", title: "Thông tin License", color: .yellow) {
                showLicense = true
            }
            adminRow(icon: "gearshape.fill", title: "Cài đặt", color: ProTheme.primary) {
                showSettings = true
            }
            adminRow(icon: "list.bullet.rectangle.fill", title: "Patch Projects", color: ProTheme.gold) {
                showProjects = true
            }
            adminRow(icon: "point.3.connected.trianglepath.dotted", title: "Pairing & quyền truy cập", color: .cyan) {
                showPairingAccess = true
            }
            adminRow(icon: "doc.text.magnifyingglass", title: "Xem Log", color: .cyan) {
                showLogs = true
            }
            adminRow(icon: "rectangle.portrait.and.arrow.right", title: "Xoá kích hoạt", color: .red) {
                showDeactivateAlert = true
            }
        }
    }

    private func adminRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(color.opacity(0.15)))

                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var zaloCard: some View {
        Button {
            if let url = URL(string: "https://zalo.me/0358648824") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 42, height: 42)

                    Image(systemName: "phone.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Liên hệ Admin qua Zalo")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))

                    Text("0358648824")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.10, blue: 0.25),
                                Color(red: 1.00, green: 0.20, blue: 0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ProTheme.gold.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: ProTheme.primary.opacity(0.4), radius: 12)
        }
        .buttonStyle(.plain)
    }

    private var creditsSection: some View {
        VStack(spacing: 8) {
            Divider().overlay(ProTheme.gold.opacity(0.2))

            Text("Developed by Admin MinhDuc")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Text("Version 1.1.1 • Build 7")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ProTheme.gold.opacity(0.7))
        }
        .padding(.top, 4)
    }

    private var proFooter: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(.green).frame(width: 9, height: 9).blur(radius: 2).opacity(0.8)
                Circle().fill(.green).frame(width: 7, height: 7)
            }

            Text("ADMIN MODE ACTIVE")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ProTheme.gold)

                Text("MINH DUC v2.0")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(ProTheme.goldGradient)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .overlay(Capsule().stroke(ProTheme.goldGradient.opacity(0.4), lineWidth: 1))
    }
}

struct LicenseInfoView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Key") {
                    LabeledContent("Key đã nhập", value: licenseManager.rememberedKey() ?? "—")
                }
                Section("Trạng thái") {
                    LabeledContent("Active", value: licenseManager.isActive ? "Có" : "Không")
                    LabeledContent("Device ID", value: DeviceID.current)
                }
                Section {
                    Button("Xoá kích hoạt", role: .destructive) {
                        licenseManager.deactivate()
                        dismiss()
                    }
                }
            }
            .navigationTitle("License Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}


// MARK: - Pairing profile and access diagnostics
// This screen imports a user-selected profile for inspection/storage only.
// It does not perform device pairing or grant access to another app's sandbox.
private struct PairingAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingImporter = false
    @State private var statusMessage = "Chưa nhập file pairing."
    @State private var importedFileName: String?
    @State private var isError = false

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var documentsAccessible: Bool {
        FileManager.default.isReadableFile(atPath: NSHomeDirectory() + "/Documents")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusCard
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Nhập file pairing", systemImage: "doc.badge.plus")
                            .font(.headline)
                        Text("Chọn file do chính bạn tạo hoặc lấy từ nguồn đáng tin cậy. OGIOS sẽ kiểm tra định dạng và lưu bản sao trong vùng dữ liệu riêng của ứng dụng.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Chọn file JSON / PLIST", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        if let importedFileName {
                            Label("Đã lưu: \(importedFileName)", systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(isError ? .red : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Giới hạn quyền truy cập", systemImage: "lock.shield")
                            .font(.headline)
                        Text("• Pairing file không tự mở khóa sandbox của ứng dụng khác.\n• VPN/tunnel không đồng nghĩa với quyền đọc container.\n• Quyền truy cập được báo là khả dụng chỉ khi API iOS hoặc quyền người dùng thực sự cho phép.\n• Màn hình này chưa thực hiện giao thức ghép nối LocalDevVN/3105 vì cần giao thức và dịch vụ tương thích chính xác.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(16)
            }
            .navigationTitle("Pairing & Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json, .propertyList, .data],
                allowsMultipleSelection: false
            ) { result in
                importProfile(result)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRẠNG THÁI THIẾT BỊ")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.cyan)
            HStack {
                Label(osVersion, systemImage: "iphone")
                Spacer()
                Text("Đã phát hiện")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            HStack {
                Label("Thư mục Documents của OGIOS", systemImage: "folder")
                Spacer()
                Text(documentsAccessible ? "Đọc được" : "Không đọc được")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(documentsAccessible ? .green : .orange)
            }
            Text("Đây chỉ là kiểm tra môi trường ứng dụng hiện tại, không xác nhận quyền truy cập container của app khác.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.cyan.opacity(0.35), lineWidth: 1))
    }

    private func importProfile(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: sourceURL)
            guard !data.isEmpty, data.count <= 5 * 1_024 * 1_024 else {
                throw ImportError.invalidSize
            }
            let isJSON = (try? JSONSerialization.jsonObject(with: data)) != nil
            let isPlist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil
            guard isJSON || isPlist else { throw ImportError.invalidFormat }

            let manager = FileManager.default
            let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("PairingProfiles", isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let safeName = sourceURL.lastPathComponent.replacingOccurrences(of: "/", with: "_")
            let destination = directory.appendingPathComponent(safeName)
            try data.write(to: destination, options: .atomic)
            importedFileName = safeName
            statusMessage = "File hợp lệ và đã lưu trong dữ liệu riêng của OGIOS. Chưa ghép nối thiết bị."
            isError = false
        } catch {
            statusMessage = "Không nhập được file: \(error.localizedDescription)"
            isError = true
        }
    }

    private enum ImportError: LocalizedError {
        case invalidSize
        case invalidFormat
        var errorDescription: String? {
            switch self {
            case .invalidSize: return "File rỗng hoặc lớn hơn giới hạn 5 MB."
            case .invalidFormat: return "File không phải JSON hoặc PLIST hợp lệ."
            }
        }
    }
}
