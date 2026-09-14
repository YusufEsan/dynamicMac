import Foundation
import Security

@Observable
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let service = "com.faceisland.unlockService"
    private let account = "FaceIslandAutoUnlockPassword"
    
    public var hasSavedPassword: Bool = false
    private var memoryCachedPassword: String?
    
    private init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        if let pwd = fetchPasswordFromKeychain() {
            self.hasSavedPassword = true
            self.memoryCachedPassword = pwd
        } else {
            self.hasSavedPassword = false
            self.memoryCachedPassword = nil
        }
    }
    
    @discardableResult
    public func savePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        
        // Immediate in-memory update for 0ms instant UI responsiveness
        self.memoryCachedPassword = password
        self.hasSavedPassword = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.deleteKeychainEntry()
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            let status = SecItemAdd(query as CFDictionary, nil)
            DispatchQueue.main.async {
                if status != errSecSuccess {
                    self.hasSavedPassword = false
                    self.memoryCachedPassword = nil
                }
            }
        }
        return true
    }
    
    public func getPassword() -> String? {
        if let memory = memoryCachedPassword {
            return memory
        }
        return fetchPasswordFromKeychain()
    }
    
    private func fetchPasswordFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            let str = String(data: data, encoding: .utf8)
            self.memoryCachedPassword = str
            return str
        }
        return nil
    }
    
    public func deletePassword() {
        self.memoryCachedPassword = nil
        self.hasSavedPassword = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.deleteKeychainEntry()
        }
    }
    
    private func deleteKeychainEntry() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
