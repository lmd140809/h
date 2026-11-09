import SwiftUI

struct ContentView: View {
    @State private var licenseKey = ""
    @State private var message = "Chưa kết nối máy chủ"
    @State private var showAbout = false

    private let accent = Color(red: 0.30, green: 0.72, blue: 0.98)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.055, blue: 0.11),
                         Color(red: 0.075, green: 0.10, blue: 0.19)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        Label("TRẠNG THÁI ỨNG DỤNG", systemImage: "waveform.path")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)

                        HStack {
                            Circle().fill(.orange).frame(width: 9, height: 9)
                            Text(message)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .panel()

                    VStack(alignment: .leading, spacing: 13) {
                        Label("KÍCH HOẠT BẰNG KEY", systemImage: "key.horizontal")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)

                        TextField("Nhập KEY của bạn", text: $licenseKey)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(15)
                            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)

                        Button {
                            message = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Vui lòng nhập KEY"
                                : "Giao diện mẫu: chưa cấu hình API KEY"
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                Text("Kiểm tra KEY")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .background(accent, in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                    .panel()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("THÔNG TIN", systemImage: "info.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)

                        infoRow("Phiên bản", value: "1.0.0")
                        Divider().overlay(.white.opacity(0.1))
                        infoRow("Nền tảng", value: "iOS")
                        Divider().overlay(.white.opacity(0.1))
                        infoRow("Build", value: "GitHub Actions")
                    }
                    .panel()

                    Button { showAbout = true } label: {
                        Label("Giới thiệu ứng dụng", systemImage: "questionmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, 4)

                    Text("Ứng dụng mẫu độc lập • Không liên kết với Free Fire")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Giới thiệu", isPresented: $showAbout) {
            Button("Đóng", role: .cancel) { }
        } message: {
            Text("Đây là bộ khung SwiftUI để bạn phát triển ứng dụng riêng. Chức năng KEY hiện chỉ là giao diện minh họa; cần tích hợp API và xác thực phía máy chủ trước khi sử dụng thật.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(accent.opacity(0.16))
                    .frame(width: 76, height: 76)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(accent)
            }
            Text("MIZZE REBUILD")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white)
            Text("ỨNG DỤNG iOS • SWIFTUI")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value).foregroundStyle(.white).fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

private extension View {
    func panel() -> some View {
        padding(17)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
