import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
    
    // MARK: - State
    @Published private(set) var expirationDate: Date? = nil
    @Published private(set) var isActive: Bool = true // Luôn luôn là true để vào app không cần key
    @Published private(set) var isBusy = false
    @Published private(set) var message: String? = "Sẵn sàng sử dụng"
    @Published private(set) var contactOwner: String? = "0358648824"
    @Published var rememberKey = true
    @Published var forceLogout = false
    @Published var announcement: Announcement?

    private let keychain = Keychain(service: "com.minhduc.admin.activation")
    private let keyAccount = "license-key"
    private let lastCheckAccount = "license-last-check"

    // Khởi tạo: Luôn đặt trạng thái active = true
    init() { 
        self.isActive = true 
    }

    // Các hàm kiểm tra key (giữ lại để tránh lỗi nếu UI có gọi tới, nhưng không làm gì cả)
    var hasRememberedKey: Bool { true } // Luôn báo là đã có key
    func rememberedKey() -> String? { "ACTIVATED" }
    func refresh() { isActive = true }

    // MARK: - Lifecycle
    func beginLaunchSession() {
        isActive = true
        message = "Sẵn sàng sử dụng"
    }

    // MARK: - Kích hoạt (Không cần làm gì)
    func activate(key: String) {
        // Không làm gì cả vì app đã mặc định active
        isActive = true
        message = "Sẵn sàng sử dụng"
    }

    // MARK: - Hủy kích hoạt (Không cần làm gì)
    func deactivate() {
        // Không cho phép hủy kích hoạt
        isActive = true
        message = "Sẵn sàng sử dụng"
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

// MARK: - Keychain (Giữ lại để tránh lỗi nếu có file khác gọi tới)
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
