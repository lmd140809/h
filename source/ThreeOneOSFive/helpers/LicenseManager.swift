import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
    
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

    init() { isActive = hasRememberedKey }

    var hasRememberedKey: Bool { !(keychain.string(keyAccount) ?? "").isEmpty }
    func rememberedKey() -> String? { keychain.string(keyAccount) }
    func refresh() { isActive = hasRememberedKey }

    // MARK: - Lifecycle
    func beginLaunchSession() {
        isActive = hasRememberedKey
        message = isActive ? "Sẵn sàng sử dụng" : "Cần nhập key — vui lòng nhập access key"
    }

    // MARK: - Kích hoạt
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
        
        // Giả lập quá trình kiểm tra (Bạn sẽ cần viết logic mới ở đây nếu không dùng GitHub)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Giả lập đợi 1 giây
            self.isBusy = false
            self.message = "Tính năng kết nối server đã bị gỡ bỏ."
            // finishActivation(key: trimmed, matched: ..., announcement: nil)
        }
    }

    private func finishActivation(key: String, announcement: Announcement?) {
        if rememberKey { keychain.save(key, account: keyAccount) }
        keychain.save(ISO8601DateFormatter().string(from: Date()), account: lastCheckAccount)
        self.announcement = announcement
        // expirationDate = ... (Cần logic mới)
        isActive = true
        forceLogout = false
        message = "Kích hoạt thành công"
    }

    // MARK: - Hủy kích hoạt
    func deactivate() {
        keychain.delete(keyAccount)
        keychain.delete(lastCheckAccount)
        isActive = false
        expirationDate = nil
        forceLogout = false
        announcement = nil
        message = "Đã xoá kích hoạt"
    }
}

// MARK: - Models
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

// MARK: - Device ID
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
