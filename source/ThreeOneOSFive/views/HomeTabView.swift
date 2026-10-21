import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var currentTime = Date()
    @State private var appeared = false
    @State private var serverStatus: ServerStatus = .checking

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                welcomeBanner
                quickStatsRow
                vipStatusCard
                gameInfoCard
                deviceStatusCard
                serverStatusBar
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
        }
        // ⚡ TỰ ĐỘNG HIỆN THÔNG BÁO KHI CÓ UPDATE TỪ ADMIN
        .alert(item: $licenseManager.announcement) { announcement in
            Alert(
                title: Text(announcement.isUrgent ? "🚨 THÔNG BÁO KHẨN" : "📢 THÔNG BÁO TỪ ADMIN"),
                message: Text("\(announcement.title)\n\n\(announcement.message)\n\nNgày: \(announcement.date)"),
                dismissButton: .default(Text("Đã hiểu"))
            )
        }
        .onReceive(clockTimer) { _ in currentTime = Date() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            Task { await checkServerStatus() }
        }
    }

    // MARK: - Welcome Banner
    private var welcomeBanner: some View {
        HStack(spacing: 12) {
            Text(welcomeEmoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text(welcomeGreeting)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Hệ thống sẵn sàng • 4 patch")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ProTheme.gold.opacity(0.3), lineWidth: 1)
        )
    }

    private var welcomeGreeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<11:  return "Chào buổi sáng, Admin!"
        case 11..<18: return "Chào buổi chiều, Admin!"
        case 18..<22: return "Chào buổi tối, Admin!"
        default:      return "Khuya rồi, nghỉ ngơi nhé!"
        }
    }

    private var welcomeEmoji: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<11:  return "☀️"
        case 11..<18: return "🌤"
        case 18..<22: return "🌙"
        default:      return "💤"
        }
    }

    // MARK: - Quick Stats
    private var quickStatsRow: some View {
        HStack(spacing: 8) {
            QuickStatCard(icon: "bolt.fill", value: "4", label: "PATCH", color: ProTheme.primary)
            QuickStatCard(icon: "checkmark.seal.fill", value: appState.isSupported ? "OK" : "NO", label: "SUPPORT", color: appState.isSupported ? .green : .red)
            QuickStatCard(icon: "cpu", value: AppInfo.shortOSVersion, label: "iOS", color: ProTheme.gold)
            QuickStatCard(icon: "clock.fill", value: "24/7", label: "ONLINE", color: .orange)
        }
    }

    // MARK: - VIP Status Card
    private var vipStatusCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ProTheme.goldGradient)

                Text("VIP MEMBER")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(ProTheme.goldGradient)

                Spacer()

                Text("ACTIVE")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KEY")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(licenseManager.rememberedKey() ?? "MINHDUC-VIP-001")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("HẾT HẠN")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(expiryText)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(ProTheme.gold)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ProTheme.goldGradient, lineWidth: 1.2)
        )
    }

    private var expiryText: String {
        guard let exp = licenseManager.expirationDate else { return "∞" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: exp)
    }

    // MARK: - Game Info Card
    private var gameInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ProTheme.primary)

                Text("GAME INFO")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(ProTheme.titleGradient)

                Spacer()
            }

            VStack(spacing: 6) {
                infoRow(icon: "gamecontroller", label: "Game", value: "Free Fire")
                infoRow(icon: "shippingbox.fill", label: "Bundle", value: "com.dts.freefireth")
                infoRow(icon: "number", label: "Version", value: "1.104.1")
                infoRow(icon: "checkmark.circle.fill", label: "Installed", value: "Có", valueColor: .green)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ProTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ProTheme.gold)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Device Status Card
    private var deviceStatusCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ProTheme.primary)

                    Text("DEVICE STATUS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(ProTheme.titleGradient)
                }

                Spacer()

                LiveIndicator(active: appState.isSupported)
            }

            deviceRow(icon: "apple.logo", label: "iOS", value: AppInfo.osVersion)
            deviceRow(icon: "iphone", label: "Model", value: AppInfo.displayMachineName)
            deviceRow(
                icon: "checkmark.seal.fill",
                label: "Support",
                value: appState.isSupported ? "SUPPORTED" : "UNSUPPORTED",
                valueColor: appState.isSupported ? .green : .red
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ProTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }

    private func deviceRow(icon: String, label: String, value: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ProTheme.gold)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .padding(.top, 10)
    }

    // MARK: - Server Status Bar
    private var serverStatusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: serverStatus.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(serverStatus.color)

            Text("Server:")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Text(serverStatus.text)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(serverStatus.color)

            Spacer()

            Text(serverStatus.latency)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().stroke(serverStatus.color.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(.green).frame(width: 8, height: 8).shadow(color: .green, radius: 4)

            Text("SYSTEM READY")
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
                    .tracking(0.5)
                    .foregroundStyle(ProTheme.goldGradient)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .overlay(Capsule().stroke(ProTheme.goldGradient.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Check Server
    private func checkServerStatus() async {
        let start = Date()
        do {
            // ⚡ TRỎ TỚI REPO PUBLIC MINHDUX
            let url = URL(string: "https://raw.githubusercontent.com/lmd140809/MinhDux/refs/heads/main/keys.json")!
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            await MainActor.run {
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    serverStatus = .online(latency: ms)
                } else {
                    serverStatus = .slow(latency: ms)
                }
            }
        } catch {
            await MainActor.run { serverStatus = .offline }
        }
    }
}
