import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
// MARK: - Cấu hình
    private let repoOwner = "lmd140809"
    private let repoName = "MinhDux"
    private let filePath = "keys.json"
    
    // Đọc token từ Info.plist (được cấu hình từ file Secrets.xcconfig)
    private var githubToken: String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "GitHubToken") as? String, 
              !token.isEmpty else {
            print("⚠️ CẢNH BÁO: Chưa cấu hình GitHubToken trong Info.plist")
            return ""
        }
        return token
    }

    private var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(filePath)")!
    }

    private static let offlineGraceDays = 3
    private static let checkInterval: TimeInterval = 60
    private static let maxBindAttempts = 3

    // MARK: - State
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String? = "0358648824"
    @Published var rememberKey = true
    @Published var forceLogout = false
    @Published var announcement: Announcement?

    private let keychain = Keychain(service: "com.minhduc.admin.activation")
    private let keyAccount = "license-key"
    private let lastCheckAccount = "license-last-check"
    private var lastAttemptAt: Date?
    private var checkTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?

    init() { isActive = hasRememberedKey }

    var hasRememberedKey: Bool { !(keychain.string(keyAccount) ?? "").isEmpty }
    func rememberedKey() -> String? { keychain.string(keyAccount) }
    func refresh() { isActive = hasRememberedKey }

    // MARK: - Lifecycle
    func beginLaunchSession() {
        isActive = hasRememberedKey
        message = isActive ? "Sẵn sàng sử dụng" : "Cần nhập key — vui lòng nhập access key"
        if isActive { startPeriodicCheck() }
    }

    private func startPeriodicCheck() {
        stopPeriodicCheck()
        checkTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshFromServer()
                try? await Task.sleep(nanoseconds: UInt64(Self.checkInterval * 1_000_000_000))
            }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshFromServer() }
        }
    }

    private func stopPeriodicCheck() {
        checkTask?.cancel()
        checkTask = nil
        if let o = foregroundObserver { NotificationCenter.default.removeObserver(o) }
        foregroundObserver = nil
    }

    // MARK: - Kích hoạt (1 key = 1 máy)
    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }

        if let last = lastAttemptAt, Date().timeIntervalSince(last) < 1 {
            message = "Vui lòng chờ một chút rồi thử lại"
            return
        }
        lastAttemptAt = Date()
        isBusy = true
        message = "Đang kiểm tra key…"
        Task { await verifyAndLockKey(trimmed) }
    }

    private func verifyAndLockKey(_ key: String) async {
        defer { isBusy = false }
        let deviceID = DeviceID.current

        do {
            for _ in 1...Self.maxBindAttempts {
                let (response, sha) = try await fetchKeysWithSha()

                guard let idx = response.keys.firstIndex(where: {
                    $0.key.caseInsensitiveCompare(key) == .orderedSame
                }) else {
                    message = "Key không tồn tại trên server"
                    return
                }
                let matched = response.keys[idx]

                if let exp = matched.expiresAt, !exp.isEmpty, Self.isExpired(exp) {
                    expirationDate = Self.parseDate(exp)
                    message = "Key đã hết hạn"
                    return
                }

                // Đã gắn máy
                if let bound = matched.deviceID, !bound.isEmpty {
                    guard bound == deviceID else {
                        message = "Key này đã gắn với thiết bị khác. Liên hệ \(contactOwner ?? "admin") để chuyển máy."
                        return
                    }
                    finishActivation(key: key, matched: matched, announcement: response.announcement)
                    return
                }

                // Chưa gắn máy → khoá máy này
                message = "Đang kích hoạt thiết bị…"
                var updated = response.keys
                updated[idx] = LicenseKey(key: matched.key, deviceID: deviceID,
                                          expiresAt: matched.expiresAt, note: matched.note)
                let newData = KeyResponse(version: response.version,
                                          updatedAt: ISO8601DateFormatter().string(from: Date()),
                                          keys: updated, announcement: response.announcement)
                do {
                    try await updateKeysOnGitHub(newData, sha: sha)
                    finishActivation(key: key, matched: matched, announcement: response.announcement)
                    return
                } catch let e as LicenseError where e.isConflict {
                    continue   // có người ghi trước → tải lại và kiểm tra lại
                }
            }
            message = "Server đang bận, vui lòng thử lại"
        } catch {
            message = (error as? LicenseError)?.message ?? "Lỗi: \(error.localizedDescription)"
        }
    }

    private func finishActivation(key: String, matched: LicenseKey, announcement: Announcement?) {
        if rememberKey { keychain.save(key, account: keyAccount) }
        keychain.save(ISO8601DateFormatter().string(from: Date()), account: lastCheckAccount)
        self.announcement = announcement
        expirationDate = matched.expiresAt.flatMap(Self.parseDate)
        isActive = true
        forceLogout = false
        message = expirationDate.map { "Kích hoạt thành công — hết hạn \(Self.formatted($0))" }
            ?? "Kích hoạt thành công"
        startPeriodicCheck()
    }

    // MARK: - Kiểm tra định kỳ
    private func refreshFromServer() async {
        guard let saved = keychain.string(keyAccount) else { return }
        do {
            let (response, _) = try await fetchKeysWithSha()

            guard let matched = response.keys.first(where: {
                $0.key.caseInsensitiveCompare(saved) == .orderedSame
            }) else {
                forceLogoutNow(reason: "Key đã bị thu hồi"); return
            }
            if let exp = matched.expiresAt, !exp.isEmpty, Self.isExpired(exp) {
                forceLogoutNow(reason: "Key đã hết hạn"); return
            }
            guard let bound = matched.deviceID, !bound.isEmpty else {
                forceLogoutNow(reason: "Key đã được đặt lại, vui lòng kích hoạt lại"); return
            }
            guard bound == DeviceID.current else {
                forceLogoutNow(reason: "Key đã kích hoạt trên máy khác"); return
            }

            keychain.save(ISO8601DateFormatter().string(from: Date()), account: lastCheckAccount)
            expirationDate = matched.expiresAt.flatMap(Self.parseDate)
            announcement = response.announcement
            message = "Sẵn sàng sử dụng"
        } catch {
            enforceOfflineGrace()   // lỗi mạng: không đăng xuất ngay
        }
    }

    private func enforceOfflineGrace() {
        guard let s = keychain.string(lastCheckAccount),
              let last = ISO8601DateFormatter().date(from: s) else { return }
        if Date().timeIntervalSince(last) / 86_400 > Double(Self.offlineGraceDays) {
            forceLogoutNow(reason: "Cần kết nối mạng để xác thực lại key")
        }
    }

    private func forceLogoutNow(reason: String) {
        stopPeriodicCheck()
        keychain.delete(keyAccount)
        keychain.delete(lastCheckAccount)
        isActive = false
        message = reason
        forceLogout = true
    }

    func deactivate() {
        stopPeriodicCheck()
        keychain.delete(keyAccount)
        keychain.delete(lastCheckAccount)
        isActive = false
        expirationDate = nil
        forceLogout = false
        announcement = nil
        message = "Đã xoá kích hoạt"
    }

    // MARK: - GitHub API
    private func authorized(_ url: URL, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 15
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return r
    }

    private func fetchKeysWithSha() async throws -> (KeyResponse, String) {
        let (data, resp) = try await URLSession.shared.data(for: authorized(apiURL))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LicenseError(message: "Không kết nối được server")
        }
        struct GitHubFile: Decodable { let content: String; let sha: String }
        let file = try JSONDecoder().decode(GitHubFile.self, from: data)
        guard let decoded = Data(base64Encoded: file.content.replacingOccurrences(of: "\n", with: "")) else {
            throw LicenseError(message: "Lỗi giải mã file")
        }
        return (try JSONDecoder().decode(KeyResponse.self, from: decoded), file.sha)
    }

    private func updateKeysOnGitHub(_ newData: KeyResponse, sha: String) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var req = authorized(apiURL, method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "message": "Bind device",
            "content": try encoder.encode(newData).base64EncodedString(),
            "sha": sha,
            "branch": "main"
        ])

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw LicenseError(message: "Không kết nối được server")
        }
        if http.statusCode == 409 || http.statusCode == 422 {
            throw LicenseError(message: "Xung đột dữ liệu", isConflict: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LicenseError(message: "Không thể khoá thiết bị lên server")
        }
    }

    // MARK: - Date helpers
    private static let parseFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static func parseDate(_ s: String) -> Date? {
        if let d = parseFormatter.date(from: s) { return d }
        parseFormatter.dateFormat = "yyyy-M-d"
        defer { parseFormatter.dateFormat = "yyyy-MM-dd" }
        return parseFormatter.date(from: s)
    }
    /// Hết hạn khi đã qua hết ngày ghi trong file
    private static func isExpired(_ s: String) -> Bool {
        guard let d = parseDate(s) else { return false }
        return d.addingTimeInterval(86_400) <= Date()
    }
    private static func formatted(_ d: Date) -> String { displayFormatter.string(from: d) }
}

// MARK: - Models
struct KeyResponse: Codable {
    let version: Int?
    let updatedAt: String?
    let keys: [LicenseKey]
    let announcement: Announcement?
}

struct LicenseKey: Codable {
    let key: String
    let deviceID: String?
    let expiresAt: String?
    let note: String?
}

struct LicenseError: Error {
    let message: String
    var isConflict = false
}

struct Announcement: Codable, Identifiable {
    var id: String { date + title }
    let title: String
    let message: String
    let date: String
    let isUrgent: Bool
}

// MARK: - Keychain
struct Keychain {
    let service: String

    private func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func string(_ account: String) -> String? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(base(account) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base(account)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func delete(_ account: String) { SecItemDelete(base(account) as CFDictionary) }
}

// MARK: - Device ID (Keychain trước, vendorID chỉ dùng để khởi tạo)
enum DeviceID {
    private static let keychain = Keychain(service: "com.minhduc.device")
    private static let account = "device-id"

    static var current: String {
        if let stored = keychain.string(account) { return stored }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        keychain.save(id, account: account)
        return id
    }
}
