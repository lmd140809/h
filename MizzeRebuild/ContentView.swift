import SwiftUI
import Foundation

struct ContentView: View {
    @AppStorage("proxyEnabled") private var proxyEnabled = false
    @AppStorage("proxyHost") private var proxyHost = ""
    @AppStorage("proxyPort") private var proxyPort = "8080"
    @AppStorage("apiBaseURL") private var apiBaseURL = "https://your-domain.example"
    @AppStorage("configURL") private var configURL = "https://your-domain.example/config.json"

    @State private var key = ""
    @State private var status = "Chưa kiểm tra kết nối"
    @State private var busy = false
    @State private var downloadedConfig = "Chưa tải cấu hình"
    @State private var showInfo = false

    private let accent = Color(red: 0.30, green: 0.72, blue: 0.98)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.035, green: 0.055, blue: 0.11), Color(red: 0.075, green: 0.10, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        panel("PROXY", icon: "network") {
                            Toggle("Bật proxy cho các yêu cầu của ứng dụng", isOn: $proxyEnabled).tint(accent).foregroundStyle(.white)
                            TextField("Địa chỉ máy chủ (host hoặc IP)", text: $proxyHost).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            TextField("Cổng", text: $proxyPort).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            Button { Task { await testProxy() } } label: { actionLabel("Kiểm tra proxy", icon: "antenna.radiowaves.left.and.right") }.disabled(busy)
                            Text(status).font(.footnote).foregroundStyle(.white.opacity(0.75))
                            Text("Proxy chỉ áp dụng cho các kết nối mạng do ứng dụng này tạo ra; không chuyển hướng lưu lượng của game hoặc ứng dụng khác.").font(.caption2).foregroundStyle(.white.opacity(0.55))
                        }
                        panel("TẢI CẤU HÌNH", icon: "arrow.down.doc") {
                            TextField("HTTPS URL cấu hình JSON", text: $configURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                            Button { Task { await downloadConfig() } } label: { actionLabel("Tải cấu hình", icon: "arrow.down.circle") }.disabled(busy)
                            Text(downloadedConfig).font(.footnote).foregroundStyle(.white.opacity(0.75))
                        }
                        panel("KÍCH HOẠT KEY", icon: "key.horizontal") {
                            SecureField("Nhập KEY", text: $key).textFieldStyle(.roundedBorder)
                            Button { Task { await validateKey() } } label: { actionLabel("Xác thực KEY qua API", icon: "checkmark.shield") }.disabled(busy)
                            Text("Cần API HTTPS do bạn quản lý, theo định dạng POST /v1/keys/validate. Chức năng chưa thể xác thực khi chưa cấu hình máy chủ thật.").font(.caption2).foregroundStyle(.white.opacity(0.55))
                        }
                        panel("MÁY CHỦ API", icon: "server.rack") {
                            TextField("Base URL HTTPS của API", text: $apiBaseURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                            Text("Không nhập KEY hoặc dữ liệu riêng tư vào máy chủ HTTP không mã hóa.").font(.caption2).foregroundStyle(.orange.opacity(0.9))
                        }
                        Button { showInfo = true } label: { Label("Thông tin ứng dụng và quyền riêng tư", systemImage: "info.circle") }.foregroundStyle(.white.opacity(0.8)).padding(.vertical, 8)
                        Text("Mizze Rebuild • SwiftUI • Bản độc lập").font(.caption2).foregroundStyle(.white.opacity(0.4)).padding(.bottom, 20)
                    }.padding(18)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .alert("Thông tin", isPresented: $showInfo) { Button("Đóng", role: .cancel) {} } message: {
                Text("Ứng dụng chỉ dùng proxy cho request do chính app gửi. Không tích hợp patch, hook, ESP, tự động ngắm hoặc can thiệp tiến trình game. Cấu hình tải về được lưu trong vùng Documents riêng của ứng dụng.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 9) {
            Image(systemName: "square.stack.3d.up.fill").font(.system(size: 34)).foregroundStyle(accent).padding(20).background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))
            Text("MIZZE REBUILD").font(.system(size: 25, weight: .black, design: .rounded)).tracking(1.3).foregroundStyle(.white)
            Text("PROXY • CONFIG • KEY API").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    private func panel<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: icon).font(.caption.weight(.bold)).tracking(0.7).foregroundStyle(accent)
            content()
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
            .foregroundStyle(Color.black.opacity(0.85)).background(accent, in: RoundedRectangle(cornerRadius: 12))
    }

    private func makeSession() throws -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        if proxyEnabled {
            let host = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty, let port = Int(proxyPort), (1...65535).contains(port) else {
                throw AppError.message("Nhập host và cổng proxy hợp lệ.")
            }
            config.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": host, "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": host, "HTTPSPort": port
            ]
        }
        return URLSession(configuration: config)
    }

    @MainActor private func testProxy() async {
        busy = true; defer { busy = false }
        do {
            let session = try makeSession()
            defer { session.invalidateAndCancel() }
            let url = URL(string: "https://api.ipify.org?format=json")!
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw AppError.message("Máy chủ kiểm tra trả về lỗi HTTP.") }
            let result = String(data: data, encoding: .utf8) ?? "Đã kết nối"
            status = "Kết nối thành công: \(result)"
        } catch { status = "Lỗi: \(error.localizedDescription)" }
    }

    @MainActor private func downloadConfig() async {
        busy = true; defer { busy = false }
        do {
            guard let url = URL(string: configURL), url.scheme == "https" else { throw AppError.message("URL cấu hình phải dùng HTTPS.") }
            let session = try makeSession(); defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw AppError.message("Tải cấu hình thất bại: HTTP không thành công.") }
            _ = try JSONSerialization.jsonObject(with: data)
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try data.write(to: folder.appendingPathComponent("remote-config.json"), options: .atomic)
            downloadedConfig = "Đã tải và lưu cấu hình JSON (\(data.count) byte)."
        } catch { downloadedConfig = "Lỗi: \(error.localizedDescription)" }
    }

    @MainActor private func validateKey() async {
        busy = true; defer { busy = false }
        do {
            guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppError.message("Bạn chưa nhập KEY.") }
            guard let base = URL(string: apiBaseURL), base.scheme == "https", let url = URL(string: "/v1/keys/validate", relativeTo: base) else { throw AppError.message("Hãy cấu hình Base URL HTTPS của API.") }
            let session = try makeSession(); defer { session.invalidateAndCancel() }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["key": key, "platform": "ios", "appVersion": "1.0.0"])
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AppError.message("Phản hồi API không hợp lệ.") }
            let body = String(data: data, encoding: .utf8) ?? ""
            status = "API trả về HTTP \(http.statusCode): \(body.prefix(240))"
        } catch { status = "Lỗi KEY/API: \(error.localizedDescription)" }
    }
}

private enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
