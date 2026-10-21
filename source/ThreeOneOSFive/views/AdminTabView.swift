import SwiftUI

// MARK: - Helpers dùng chung

private extension LicenseManager {
    /// Số ngày còn lại (tính hết ngày hết hạn), nil = không giới hạn
    var daysRemaining: Int? {
        guard let exp = expirationDate else { return nil }
        let end = exp.addingTimeInterval(86_400)
        return max(0, Int(ceil(end.timeIntervalSinceNow / 86_400)))
    }

    /// ABCD-1234-EFGH → ABCD••••EFGH (an toàn khi chụp màn hình)
    var maskedKey: String {
        guard let key = rememberedKey(), !key.isEmpty else { return "—" }
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return key.prefix(4) + String(repeating: "•", count: key.count - 8) + key.suffix(4)
    }

    var contact: String { contactOwner ?? "0358648824" }
}

// Đặt tên BuildInfo để không trùng với AppInfo trong Utils.swift
private enum BuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}

private enum AdminSheet: String, Identifiable {
    case settings, logs, projects, license
    var id: String { rawValue }
}

// MARK: - Admin Tab

struct AdminTabView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @Environment(\.openURL) private var openURL
    @State private var sheet: AdminSheet?
    @State private var showDeactivateAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                profileHeader
                if let announcement = licenseManager.announcement {
                    announcementCard(announcement)
                }
                adminOptions
                zaloCard
                creditsSection
                proFooter
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .settings: SettingsView()
            case .logs:     LogView()
            case .projects: PatchProjectsView()
            case .license:  LicenseInfoView()
            }
        }
        .alert("Xoá kích hoạt?", isPresented: $showDeactivateAlert) {
            Button("Huỷ", role: .cancel) { }
            Button("Xoá", role: .destructive) { licenseManager.deactivate() }
        } message: {
            Text("Bạn sẽ cần nhập lại key để vào app.")
        }
    }

    // MARK: Header

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
            .accessibilityHidden(true)

            Text("Admin MinhDuc")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Developer • Patch Master")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ProTheme.gold.opacity(0.9))

            HStack(spacing: 8) {
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

                expiryBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RadialGradient(colors: [ProTheme.gold.opacity(0.1), .clear],
                                         center: .top, startRadius: 0, endRadius: 200))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ProTheme.goldGradient, lineWidth: 1.3)
        )
    }

    @ViewBuilder
    private var expiryBadge: some View {
        let days = licenseManager.daysRemaining
        let color: Color = {
            guard let days else { return .green }
            return days == 0 ? .red : (days <= 7 ? .orange : .green)
        }()
        let text = days.map { $0 == 0 ? "Hết hạn hôm nay" : "Còn \($0) ngày" } ?? "Vĩnh viễn"

        HStack(spacing: 4) {
            Image(systemName: "clock.fill").font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 9, weight: .black, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        .accessibilityLabel("Hạn dùng: \(text)")
    }

    // MARK: Announcement

    private func announcementCard(_ a: Announcement) -> some View {
        let color: Color = a.isUrgent ? .red : ProTheme.gold
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.isUrgent ? "exclamationmark.triangle.fill" : "megaphone.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(a.title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(a.message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                Text(a.date)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Options

    private var adminOptions: some View {
        VStack(spacing: 10) {
            adminRow(icon: "key.fill", title: "Thông tin License", color: .yellow) { sheet = .license }
            adminRow(icon: "gearshape.fill", title: "Cài đặt", color: ProTheme.primary) { sheet = .settings }
            adminRow(icon: "list.bullet.rectangle.fill", title: "Patch Projects", color: ProTheme.gold) { sheet = .projects }
            adminRow(icon: "doc.text.magnifyingglass", title: "Xem Log", color: .cyan) { sheet = .logs }
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
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: Zalo

    private var zaloCard: some View {
        Button {
            if let url = URL(string: "https://zalo.me/\(licenseManager.contact)") { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 42, height: 42)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Liên hệ Admin qua Zalo")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(licenseManager.contact)
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
                    .fill(LinearGradient(
                        colors: [Color(red: 0.85, green: 0.10, blue: 0.25),
                                 Color(red: 1.00, green: 0.20, blue: 0.35)],
                        startPoint: .leading, endPoint: .trailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ProTheme.gold.opacity(0.55), lineWidth: 1))
            .shadow(color: ProTheme.primary.opacity(0.4), radius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Liên hệ Admin qua Zalo, số \(licenseManager.contact)")
    }

    // MARK: Footer

    private var creditsSection: some View {
        VStack(spacing: 8) {
            Divider().overlay(ProTheme.gold.opacity(0.2))
            Text("Developed by Admin MinhDuc")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text("Version \(BuildInfo.version) • Build \(BuildInfo.build)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ProTheme.gold.opacity(0.7))
        }
        .padding(.top, 4)
    }

    private var proFooter: some View {
        let active = licenseManager.isActive
        let dot: Color = active ? .green : .red

        return HStack(spacing: 8) {
            ZStack {
                Circle().fill(dot).frame(width: 9, height: 9).blur(radius: 2).opacity(0.8)
                Circle().fill(dot).frame(width: 7, height: 7)
            }

            Text(active ? "LICENSE ACTIVE" : "LICENSE INACTIVE")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ProTheme.gold)
                Text("MINH DUC v\(BuildInfo.version)")
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

// MARK: - License Info

struct LicenseInfoView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeactivateAlert = false
    @State private var copied = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section("Key") {
                    LabeledContent("Key đã nhập", value: licenseManager.maskedKey)
                        .privacySensitive()
                }

                Section("Trạng thái") {
                    LabeledContent("Kích hoạt") {
                        Label(licenseManager.isActive ? "Đang hoạt động" : "Chưa kích hoạt",
                              systemImage: licenseManager.isActive ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(licenseManager.isActive ? .green : .red)
                    }
                    LabeledContent("Hết hạn", value: expiryText)
                    if let days = licenseManager.daysRemaining {
                        LabeledContent("Còn lại", value: "\(days) ngày")
                    }
                }

                Section {
                    LabeledContent("Device ID") {
                        Text(DeviceID.current)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                    Button {
                        UIPasteboard.general.string = DeviceID.current
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Đã sao chép" : "Sao chép Device ID",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    ShareLink(item: DeviceID.current) {
                        Label("Gửi Device ID cho Admin", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Thiết bị")
                } footer: {
                    Text("Mỗi key chỉ dùng được trên 1 thiết bị. Khi đổi máy, gửi Device ID cho \(licenseManager.contact) để được chuyển key.")
                }

                Section {
                    Button("Xoá kích hoạt", role: .destructive) { showDeactivateAlert = true }
                }
            }
            .navigationTitle("License Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Đóng") { dismiss() } }
            }
            .alert("Xoá kích hoạt?", isPresented: $showDeactivateAlert) {
                Button("Huỷ", role: .cancel) { }
                Button("Xoá", role: .destructive) {
                    licenseManager.deactivate()
                    dismiss()
                }
            } message: {
                Text("Bạn sẽ cần nhập lại key để vào app.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var expiryText: String {
        licenseManager.expirationDate.map { Self.dateFormatter.string(from: $0) } ?? "Không giới hạn"
    }
}
