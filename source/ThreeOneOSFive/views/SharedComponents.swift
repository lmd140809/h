import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - PRO THEME
// ═══════════════════════════════════════════════════════════════

enum ProTheme {
    static let primary = Color(red: 0.95, green: 0.15, blue: 0.28)
    static let gold    = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let goldLight = Color(red: 1.00, green: 0.92, blue: 0.55)
    static let dark    = Color(red: 0.05, green: 0.02, blue: 0.04)
    static let secondaryAccent = Color(red: 0.20, green: 0.85, blue: 1.00)

    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.15, blue: 0.28),
            Color(red: 1.00, green: 0.35, blue: 0.45)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.78, blue: 0.20),
            Color(red: 1.00, green: 0.92, blue: 0.55),
            Color(red: 1.00, green: 0.78, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let titleGradient = LinearGradient(
        colors: [.white, Color(red: 1.00, green: 0.92, blue: 0.55)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ANIMATED HYPER BACKDROP
// ═══════════════════════════════════════════════════════════════

struct AnimatedHyperBackdrop: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.02, blue: 0.04),
                        Color.black,
                        Color(red: 0.06, green: 0.01, blue: 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(ProTheme.primary.opacity(0.25))
                    .frame(width: 340, height: 340)
                    .blur(radius: 110)
                    .offset(x: animate ? 140 : -140, y: -proxy.size.height * 0.30)

                Circle()
                    .fill(ProTheme.gold.opacity(0.14))
                    .frame(width: 300, height: 300)
                    .blur(radius: 120)
                    .offset(x: animate ? -120 : 120, y: proxy.size.height * 0.32)

                Circle()
                    .fill(ProTheme.primary.opacity(0.10))
                    .frame(width: 220, height: 220)
                    .blur(radius: 90)
                    .offset(x: 0, y: animate ? 90 : -90)

                GridOverlay()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
}

struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 48

            stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(
                path,
                with: .color(ProTheme.primary.opacity(0.045)),
                lineWidth: 1
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PARTICLE FIELD
// ═══════════════════════════════════════════════════════════════

struct ParticleField: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.blur)
                        .opacity(particle.opacity)
                        .position(particle.position)
                }
            }
            .onAppear {
                generateParticles(in: proxy.size)
                startAnimation(in: proxy.size)
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<18).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.15...0.5),
                color: Bool.random() ? ProTheme.gold : ProTheme.primary,
                blur: CGFloat.random(in: 0.5...2)
            )
        }
    }

    private func startAnimation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in particles.indices {
                var p = particles[i]
                p.position.y -= CGFloat.random(in: 0.2...0.8)
                if p.position.y < -10 {
                    p.position.y = size.height + 10
                    p.position.x = CGFloat.random(in: 0...size.width)
                }
                particles[i] = p
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
    let color: Color
    let blur: CGFloat
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PRO PATCH CARD
// ═══════════════════════════════════════════════════════════════

struct ProPatchCard: View {
    let name: String
    let target: String
    let color: Color
    @Binding var isEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.22))
                            .frame(width: 34, height: 34)
                            .blur(radius: isEnabled && pulse ? 8 : 0)

                        Circle()
                            .fill(color.opacity(0.28))
                            .frame(width: 32, height: 32)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(color)
                            .shadow(color: isEnabled ? color : .clear, radius: 4)
                    }

                    Spacer()

                    Text(isEnabled ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(isEnabled ? .green : .white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(isEnabled ? Color.green.opacity(0.18) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            Capsule().stroke(isEnabled ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }

                Text(name)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(target)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(color)

                HStack(spacing: 7) {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.white.opacity(0.28))
                        .frame(width: 8, height: 8)
                        .shadow(color: isEnabled ? .green : .clear, radius: isEnabled && pulse ? 6 : 0)

                    Text(isEnabled ? "PATCH ACTIVE" : "ACTIVATE PATCH")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .padding(15)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.58))

                    if isEnabled {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [color.opacity(0.18), .clear],
                                    center: .topTrailing,
                                    startRadius: 0,
                                    endRadius: 160
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isEnabled ? color.opacity(0.9) : color.opacity(0.28),
                        lineWidth: isEnabled ? 1.8 : 1
                    )
            )
            .shadow(color: isEnabled ? color.opacity(0.4) : .clear, radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.55 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PATCH UNLOCK PROMPT
// ═══════════════════════════════════════════════════════════════

struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Mật khẩu gói", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }

                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Nhập mật khẩu để mở khoá gói trên thiết bị này.")
                }
            }
            .navigationTitle("Mở khoá gói")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mở khoá", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - QUICK STAT CARD
// ═══════════════════════════════════════════════════════════════

struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - NOTIFICATION BELL
// ═══════════════════════════════════════════════════════════════

struct NotificationBellButton: View {
    @State private var pulse = false
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProTheme.gold)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .overlay(Circle().stroke(ProTheme.goldGradient, lineWidth: 1.2))

                Text("1")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(ProTheme.primary))
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .offset(x: 12, y: -12)
                    .scaleEffect(pulse ? 1.15 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .sheet(isPresented: $showSheet) {
            NotificationSheet()
        }
    }
}

struct NotificationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    notificationRow(
                        icon: "crown.fill",
                        title: "Chào mừng đến MINH DUC PRO",
                        message: "Cảm ơn bạn đã sử dụng dịch vụ!",
                        time: "Vừa xong",
                        color: ProTheme.gold
                    )
                    notificationRow(
                        icon: "bolt.fill",
                        title: "Patch mới đã sẵn sàng",
                        message: "Nhẹ Tâm đã được cập nhật.",
                        time: "5 phút trước",
                        color: ProTheme.primary
                    )
                    notificationRow(
                        icon: "phone.fill",
                        title: "Hỗ trợ 24/7",
                        message: "Liên hệ Zalo 0358648824.",
                        time: "Hôm qua",
                        color: .green
                    )
                }
            }
            .navigationTitle("Thông báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func notificationRow(icon: String, title: String, message: String, time: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                Text(time)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - LIVE INDICATOR
// ═══════════════════════════════════════════════════════════════

struct LiveIndicator: View {
    let active: Bool
    @State private var blink = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill((active ? Color.green : Color.red).opacity(0.5))
                    .frame(width: 10, height: 10)
                    .blur(radius: 2)
                    .opacity(blink ? 1 : 0.3)

                Circle()
                    .fill(active ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
            }

            Text(active ? "LIVE" : "OFF")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(active ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill((active ? Color.green : Color.red).opacity(0.12))
        )
        .overlay(
            Capsule().stroke((active ? Color.green : Color.red).opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                blink = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SERVER STATUS ENUM
// ═══════════════════════════════════════════════════════════════

enum ServerStatus {
    case checking
    case online(latency: Int)
    case slow(latency: Int)
    case offline

    var icon: String {
        switch self {
        case .checking: return "arrow.triangle.2.circlepath"
        case .online:   return "checkmark.circle.fill"
        case .slow:     return "exclamationmark.triangle.fill"
        case .offline:  return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .gray
        case .online:   return .green
        case .slow:     return .yellow
        case .offline:  return .red
        }
    }

    var text: String {
        switch self {
        case .checking: return "Checking…"
        case .online:   return "Online"
        case .slow:     return "Slow"
        case .offline:  return "Offline"
        }
    }

    var latency: String {
        switch self {
        case .checking: return "—"
        case .online(let ms): return "\(ms)ms"
        case .slow(let ms):   return "\(ms)ms"
        case .offline:  return "—"
        }
    }
}
