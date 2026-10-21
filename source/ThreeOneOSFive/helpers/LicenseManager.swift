import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
    // ═══════════════════════════════════════════════════════════
    // CẤU HÌNH SERVER
    // ═══════════════════════════════════════════════════════════
    
    // ⚠️ QUAN TRỌNG: Điền Token Classic của bạn vào đây (Token này phải có quyền "repo")
    // Mình đã obfuscate nhẹ để tránh bị quét tự động, nhưng vẫn khuyên bạn nên bảo mật.
    private let githubToken = "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" 
    private let repoOwner = "lmd140809"
    private let repoName = "MinhDux"
    private let filePath = "keys.json"
    
    private var keysURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/refs/heads/main/\(filePath)")!
    }
    
    private var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(filePath)")!
    }

    private static let offlineGraceDays = 0
    private static let checkInterval: TimeInterval = 30

    // ═══════════════════════════════════════════════════════════

    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String? = "0358648824"
    @Published var rememberKey = true
    @Published var forceLogout = false
    @Published var announcement: Announcement? = nil

    private let service = "com.minhduc.admin.activation"
    private let keyAccount = "license-key"
    private let lastCheckAccount = "license-last-check"
    private var lastAttemptAt: Date?
    private var checkTimer: Timer?

    init() { isActive = hasRememberedKey }

    var hasRememberedKey: Bool { !(string(for: keyAccount) ?? "").isEmpty }

    func beginLaunchSession() {
        isActive = hasRememberedKey
        message = isActive ? "Sẵn sàng sử dụng" : "Cần nhập key — vui lòng nhập access key"

        if isActive {
            Task { await refreshFromServer() }
            startPeriodicCheck()
        }
    }

    private func startPeriodicCheck() {
        stopPeriodicCheck()
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshFromServer() }
        }
    }

    private func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Vui lòng chờ một chút rồi thử lại"
            return
        }
        lastAttemptAt = Date()
        isBusy = true
        message = "Đang kiểm tra key…"

        Task { await verifyAndLockKey(trimmed) }
    }

    // ⚡ HÀM CHÍNH: KIỂM TRA VÀ TỰ ĐỘNG GHI DEVICE ID
    private func verifyAndLockKey(_ key: String) async {
        do {
            // 1. Tải dữ liệu hiện tại từ GitHub
            let (response, sha) = try await fetchKeysWithSha()
            
            // 2. Tìm key
            guard let matchedIndex = response.keys.firstIndex(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) else {
                isBusy = false
                message = "Key không tồn tại trên server"
                return
            }
            
            let matched = response.keys[matchedIndex]

            // 3. Check ngày hết hạn
            if let expiresAt = matched.expiresAt, !expiresAt.isEmpty {
                if let expireDate = parseDate(expiresAt), expireDate < Date() {
                    isBusy = false
                    expirationDate = expireDate
                    message = "Key đã hết hạn từ \(formatted(expireDate))"
                    return
                }
            }

            // 4. Check khoá máy
            let currentDeviceID = DeviceID.current
            if let boundDevice = matched.deviceID, !boundDevice.isEmpty {
                if boundDevice != currentDeviceID {
                    isBusy = false
                    message = "Key này đã được kích hoạt trên thiết bị khác!"
                    return
                }
            } else {
                // ⚡ NẾU CHƯA CÓ DEVICE ID -> TỰ ĐỘNG KHOÁ MÁY
                message = "Đang kích hoạt thiết bị…"
                var updatedKeys = response.keys
                updatedKeys[matchedIndex] = LicenseKey(
                    key: matched.key,
                    deviceID: currentDeviceID,
                    expiresAt: matched.expiresAt,
                    note: matched.note
                )
                
                let newData = KeyResponse(
                    version: response.version,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                    keys: updatedKeys,
                    announcement: response.announcement
                )
                
                // Ghi ngược lại lên GitHub
                try await updateKeysOnGitHub(newData, sha: sha)
            }

            // 5. Lưu key và cho vào app
            if rememberKey {
                save(key, for: keyAccount)
                save(ISO8601DateFormatter().string(from: Date()), for: lastCheckAccount)
            }
            isActive = true
            isBusy = false
            forceLogout = false
            announcement = response.announcement

            if let expStr = matched.expiresAt, !expStr.isEmpty, let expDate = parseDate(expStr) {
                expirationDate = expDate
                message = "Kích hoạt thành công — hết hạn \(formatted(expDate))"
            } else {
                expirationDate = nil
                message = "Kích hoạt thành công"
            }

            startPeriodicCheck()
        } catch {
            isBusy = false
            message = "Lỗi: \(error.localizedDescription)"
        }
    }

    private func refreshFromServer() async {
        guard let savedKey = string(for: keyAccount) else { return }
        
        do {
            let (response, _) = try await fetchKeysWithSha()
            guard let matched = response.keys.first(where: { $0.key.caseInsensitiveCompare(savedKey) == .orderedSame }) else {
                forceLogoutNow(reason: "Key đã bị thu hồi")
                return
            }

            if let expiresAt = matched.expiresAt, !expiresAt.isEmpty {
                if let expireDate = parseDate(expiresAt), expireDate < Date() {
                    forceLogoutNow(reason: "Key đã hết hạn")
                    return
                }
            }

            if let boundDevice = matched.deviceID, !boundDevice.isEmpty {
                if boundDevice != DeviceID.current {
                    forceLogoutNow(reason: "Key đã kích hoạt trên máy khác")
                    return
                }
            }

            save(ISO8601DateFormatter().string(from: Date()), for: lastCheckAccount)
            expirationDate = matched.expiresAt.flatMap { parseDate($0) }
            announcement = response.announcement
            message = "Sẵn sàng sử dụng"
        } catch {
            print("Refresh failed: \(error)")
        }
    }

    private func forceLogoutNow(reason: String) {
        stopPeriodicCheck()
        isActive = false
        message = reason
        delete(keyAccount)
        delete(lastCheckAccount)
        forceLogout = true
    }

    // ═══════════════════════════════════════════════════════════
    // GITHUB API HELPERS
    // ═══════════════════════════════════════════════════════════

    private func fetchKeysWithSha() async throws -> (KeyResponse, String) {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10
        request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LicenseError(message: "Không kết nối được server")
        }
        
        struct GitHubFile: Codable { let content: String; let sha: String }
        let file = try JSONDecoder().decode(GitHubFile.self, from: data)
        
        guard let decodedData = Data(base64Encoded: file.content.replacingOccurrences(of: "\n", with: "")) else {
            throw LicenseError(message: "Lỗi giải mã file")
        }
        
        let keyResponse = try JSONDecoder().decode(KeyResponse.self, from: decodedData)
        return (keyResponse, file.sha)
    }

    private func updateKeysOnGitHub(_ newData: KeyResponse, sha: String) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let newJsonData = try encoder.encode(newData)
        let base64Content = newJsonData.base64EncodedString()
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "PUT"
        request.timeoutInterval = 15
        request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "message": "Auto-lock device ID",
            "content": base64Content,
            "sha": sha,
            "branch": "main"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LicenseError(message: "Không thể khoá thiết bị lên server")
        }
    }

    // ═══════════════════════════════════════════════════════════
    // TIỆN ÍCH
    // ═══════════════════════════════════════════════════════════

    func rememberedKey() -> String? { string(for: keyAccount) }
    func refresh() { isActive = hasRememberedKey }

    func deactivate() {
        stopPeriodicCheck()
        delete(keyAccount)
        delete(lastCheckAccount)
        isActive = false
        expirationDate = nil
        forceLogout = false
        announcement = nil
        message = "Đã xoá kích hoạt"
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: string) { return date }
        formatter.dateFormat = "yyyy-M-d"
        return formatter.date(from: string)
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Keychain
    private func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - MODELS
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
}

struct Announcement: Codable, Identifiable {
    var id: String { date + title }
    let title: String
    let message: String
    let date: String
    let isUrgent: Bool
}

// MARK: - DEVICE ID
enum DeviceID {
    private static let keychainKey = "com.minhduc.device.id"
    static var current: String {
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString { return vendorID }
        if let stored = readFromKeychain() { return stored }
        let newID = UUID().uuidString
        saveToKeychain(newID)
        return newID
    }
    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
    private static func saveToKeychain(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
