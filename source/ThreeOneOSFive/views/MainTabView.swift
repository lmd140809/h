import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN TAB VIEW (3 tabs: HOME / PATCH / ADMIN)
// ═══════════════════════════════════════════════════════════════

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack(alignment: .top) { // ⚡ Đổi thành .top để Banner trượt từ trên xuống
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            ParticleField()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                appHeader

                Group {
                    switch selectedTab {
                    case .home:
                        HomeTabView()
                    case .patch:
                        PatchTabView()
                    case .admin:
                        AdminTabView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
            
            // ⚡ BANNER THÔNG BÁO TỪ XA
            if let ann = licenseManager.announcement {
                AnnouncementBanner(announcement: ann)
                    .padding(.top, 50) // Đẩy xuống dưới Header
                    .zIndex(100)       // Luôn nổi lên trên cùng
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut, value: licenseManager.announcement != nil)
    }

    private var appHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(ProTheme.goldGradient)
                    .frame(width: 44, height: 44)
                    .blur(radius: 10)
                    .opacity(0.6)

                Circle()
                    .stroke(ProTheme.goldGradient, lineWidth: 1.5)
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)

                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(ProTheme.goldGradient)
                    .offset(y: -2)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(ProTheme.primaryGradient)
                    .offset(y: 7)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("HOÀNG ANH")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(ProTheme.titleGradient)

                    Text("PRO")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ProTheme.goldGradient))
                }

                Text(selectedTab.subtitle)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(ProTheme.primaryGradient)
            }

            Spacer()

            NotificationBellButton()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(ProTheme.gold.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                    .blur(radius: 8)

                                Circle()
                                    .fill(ProTheme.gold.opacity(0.2))
                                    .frame(width: 32, height: 32)
                            }

                            Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? ProTheme.gold : .white.opacity(0.5))
                        }

                        Text(tab.title)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(selectedTab == tab ? ProTheme.gold : .white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .background(
            Color.black.opacity(0.75)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(ProTheme.gold.opacity(0.3))
                        .frame(height: 1)
                }
        )
    }
}

enum MainTab: String, CaseIterable, Identifiable {
    case home, patch, admin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:  return "HOME"
        case .patch: return "PATCH"
        case .admin: return "ADMIN"
        }
    }

    var subtitle: String {
        switch self {
        case .home:  return "DASHBOARD"
        case .patch: return "PATCH CONTROL"
        case .admin: return "ADMIN PANEL"
        }
    }

    var icon: String {
        switch self {
        case .home:  return "house"
        case .patch: return "bolt"
        case .admin: return "person.crop.circle"
        }
    }

    var iconFilled: String {
        switch self {
        case .home:  return "house.fill"
        case .patch: return "bolt.fill"
        case .admin: return "person.crop.circle.fill"
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ANNOUNCEMENT BANNER (GIAO DIỆN THÔNG BÁO)
// ═══════════════════════════════════════════════════════════════

struct AnnouncementBanner: View {
    let announcement: Announcement
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(announcement.isUrgent ? .red : ProTheme.gold)
                    
                    Text(announcement.title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation { isDismissed = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                Text(announcement.message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(announcement.date)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(ProTheme.gold.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(announcement.isUrgent ? Color.red.opacity(0.6) : ProTheme.gold.opacity(0.4), lineWidth: 1.2)
            )
            .padding(.horizontal, 18)
        }
    }
}
