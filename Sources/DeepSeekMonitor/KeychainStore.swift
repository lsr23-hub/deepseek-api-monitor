import Foundation
import Security

/// Minimal Keychain wrapper for secure credential storage.
enum KeychainStore {

    enum Key: String {
        case apiKey = "com.deepseek-monitor.api-key"
        case platformToken = "com.deepseek-monitor.platform-token"
        case kuaipaoAccessToken = "com.deepseek-monitor.kuaipao-access-token"
        case kuaipaoUserId = "com.deepseek-monitor.kuaipao-user-id"
    }

    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "DeepSeekMonitor",
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "DeepSeekMonitor",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecAttrService: "DeepSeekMonitor",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
