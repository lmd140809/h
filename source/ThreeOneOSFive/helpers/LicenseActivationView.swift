import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject var manager: LicenseManager
    @State private var key = ""
    @FocusState private var keyFocused: Bool
    @State private var pulse = false
    @State private var shimmerOffset: CGFloat = -1
    @State private var appeared = false

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            Color.black.opacity(0.22)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 42)

                        logoHeader

                        VStack(spacing: 16) {
                            keyHeader

                            Text("Nhập license key để tiếp tục sử dụng")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.68))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            keyField

                            rememberToggle

                            verifyButton

                            messageBanner

                            contactButton
                        }
                        .padding(20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .fill(Color.black.opacity(0.55))

                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: [ProTheme.gold.opacity(0.10), .clear],
                                            center: .top,
                                            startRadius: 0,
                                            endRadius: 220
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .stroke(ProTheme.goldGradient, lineWidth: 1.3)
                        )
                        .shadow(color: ProTheme.gold.opacity(0.18), radius: 18)
                        .padding(.horizontal, 22)
                        .padding(.top, 26)
                        .id("activation-card")

                        Spacer(minLength: 42)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: keyFocused) { focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("activation-card", anchor: .center)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - LOGO HEADER
    // ═══════════════════════════════════════════════════════════

    private var logoHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ProTheme.goldGradient)
                    .frame(width: 82, height: 82)
                    .blur(radius: pulse ? 20 : 12)
                    .opacity(0.7)

                Circle()
                    .stroke(ProTheme.goldGradient, lineWidth: 2)
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                    .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: pulse)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.15, green: 0.02, blue: 0.05),
                                Color.black
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 66, height: 66)

                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(ProTheme.goldGradient)
                    .offset(y: -5)
                    .shadow(color: ProTheme.gold.opacity(0.8), radius: 6)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(ProTheme.primaryGradient)
                    .offset(y: 11)
                    .shadow(color: ProTheme.primary.opacity(0.8), radius: 4)
            }
            .scaleEffect(appeared ? 1 : 0.7)

            HStack(spacing: 8) {
                Text("MINH DUC")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(ProTheme.titleGradient)
                    .shadow(color: ProTheme.gold.opacity(0.35), radius: 10)

                ZStack {
                    Text("PRO")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(ProTheme.goldGradient))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.7), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 14, height: 24)
                        .offset(x: shimmerOffset * 14)
                        .blendMode(.overlay)
                        .mask(Capsule())
                }
                .frame(width: 40, height: 20)
                .clipShape(Capsule())
            }

            Text("ADMIN PANEL • PREMIUM EDITION")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(ProTheme.primaryGradient)

            VStack(spacing: 3) {
                Text("Version: 1.1.0")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Text("Package: MinhDuc")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ProTheme.gold.opacity(0.9))
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - KEY HEADER
    // ═══════════════════════════════════════════════════════════

    private var keyHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ProTheme.gold.opacity(0.18))
                    .frame(width: 34, height: 34)

                Image(systemName: manager.isBusy ? "arrow.triangle.2.circlepath" : "key.fill")
                    .foregroundStyle(ProTheme.gold)
                    .font(.system(size: 15, weight: .bold))
                    .rotationEffect(.degrees(manager.isBusy ? 360 : 0))
                    .animation(
                        manager.isBusy
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: manager.isBusy
                    )
            }

            Text(manager.isBusy ? "Đang kiểm tra với server…" : "Cần nhập key")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - KEY FIELD
    // ═══════════════════════════════════════════════════════════

    private var keyField: some View {
        TextField("License key", text: $key)
            .focused($keyFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit { activate() }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.black.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ProTheme.goldGradient, lineWidth: 1.2)
            )
            .id("license-field")
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - REMEMBER TOGGLE
    // ═══════════════════════════════════════════════════════════

    private var rememberToggle: some View {
        Toggle(isOn: $manager.rememberKey) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ProTheme.gold.opacity(0.8))
                Text("Ghi nhớ key trên thiết bị này")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .tint(ProTheme.primary)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - VERIFY BUTTON
    // ═══════════════════════════════════════════════════════════

    private var verifyButton: some View {
        Button(action: activate) {
            HStack(spacing: 9) {
                Image(systemName: manager.isBusy ? "hourglass" : "checkmark.shield.fill")
                Text(manager.isBusy ? "ĐANG XÁC MINH…" : "XÁC MINH VÀ TIẾP TỤC")
            }
            .font(.system(size: 14, weight: .black, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(ProTheme.primaryGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(ProTheme.gold.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: ProTheme.primary.opacity(0.4), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isBusy)
        .opacity(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.48 : 1)
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - MESSAGE BANNER
    // ═══════════════════════════════════════════════════════════

    @ViewBuilder
    private var messageBanner: some View {
        if let message = manager.message {
            let isError = message.contains("không tồn tại")
                || message.contains("hết hạn")
                || message.contains("máy khác")
                || message.contains("bị thu hồi")
                || message.contains("Cần nhập")
                || message.contains("Lỗi")
                || message.contains("Không kết nối")

            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(message)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(isError ? .red.opacity(0.95) : Color.green.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        (isError ? Color.red : Color.green).opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - CONTACT BUTTON
    // ═══════════════════════════════════════════════════════════

    @ViewBuilder
    private var contactButton: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(ProTheme.gold.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 4)

            Text("Cần hỗ trợ? Liên hệ Admin")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Button {
                if let url = URL(string: "https://zalo.me/0358648824") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Zalo: 0358648824")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    Capsule()
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
                .overlay(Capsule().stroke(ProTheme.gold.opacity(0.55), lineWidth: 1))
                .shadow(color: ProTheme.primary.opacity(0.5), radius: 10)
            }
            .buttonStyle(.plain)
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - ACTIONS
    // ═══════════════════════════════════════════════════════════

    private func activate() {
        keyFocused = false
        manager.activate(key: key)
    }
}
