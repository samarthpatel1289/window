import Foundation
import Security

/// Secure storage for agent credentials using iOS Keychain and UserDefaults
struct CredentialStore {
    private static let hostKey = "window.agent.host"
    private static let keychainService = "com.window.app"
    private static let keychainAccount = "agent-api-key"
    
    // MARK: - Host (UserDefaults)
    
    static func saveHost(_ host: String) {
        UserDefaults.standard.set(host, forKey: hostKey)
    }
    
    static func loadHost() -> String? {
        UserDefaults.standard.string(forKey: hostKey)
    }
    
    // MARK: - API Key (Keychain)
    
    static func saveApiKey(_ key: String) {
        let data = key.data(using: .utf8)!
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("[CredentialStore] Failed to save API key: \(status)")
        }
    }
    
    static func loadApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - Clear All
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: hostKey)
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
    
    // MARK: - Helpers
    
    static var hasSavedCredentials: Bool {
        loadHost() != nil && loadApiKey() != nil
    }
}
