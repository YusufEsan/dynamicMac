import Foundation
import CryptoKit
import Security

@Observable
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    public var hasSavedPassword: Bool = false
    private var memoryCachedPassword: String?
    
    private let vaultDirectory: URL
    private let vaultFileURL: URL
    private let keyFileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.vaultDirectory = appSupport.appendingPathComponent("FaceIsland", isDirectory: true)
        self.vaultFileURL = vaultDirectory.appendingPathComponent("auth.vault")
        self.keyFileURL = vaultDirectory.appendingPathComponent(".vault.key")
        
        setupVaultDirectory()
        cleanLegacyKeychain()
        refreshStatus()
    }
    
    private func setupVaultDirectory() {
        if !FileManager.default.fileExists(atPath: vaultDirectory.path) {
            try? FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }
    }
    
    private func cleanLegacyKeychain() {
        DispatchQueue.global(qos: .utility).async {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.faceisland.unlockService",
                kSecAttrAccount as String: "FaceIslandAutoUnlockPassword"
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
    
    private func getOrCreateSymmetricKey() -> SymmetricKey {
        if let keyData = try? Data(contentsOf: keyFileURL), keyData.count == 32 {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try? keyData.write(to: keyFileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
        return newKey
    }
    
    public func refreshStatus() {
        if let pwd = fetchPasswordFromVault() {
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
        
        self.memoryCachedPassword = password
        self.hasSavedPassword = true
        
        do {
            let key = getOrCreateSymmetricKey()
            let sealed = try AES.GCM.seal(data, using: key)
            if let combined = sealed.combined {
                try combined.write(to: vaultFileURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: vaultFileURL.path)
                return true
            }
        } catch {
            AppLogger.error("Failed to encrypt password into vault: \(error)", category: .unlock)
        }
        return false
    }
    
    public func getPassword() -> String? {
        if let memory = memoryCachedPassword {
            return memory
        }
        return fetchPasswordFromVault()
    }
    
    private func fetchPasswordFromVault() -> String? {
        guard FileManager.default.fileExists(atPath: vaultFileURL.path),
              let encryptedData = try? Data(contentsOf: vaultFileURL) else {
            return nil
        }
        
        do {
            let key = getOrCreateSymmetricKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            if let str = String(data: decryptedData, encoding: .utf8) {
                self.memoryCachedPassword = str
                return str
            }
        } catch {
            AppLogger.error("Failed to decrypt password from vault: \(error)", category: .unlock)
        }
        return nil
    }
    
    public func deletePassword() {
        self.memoryCachedPassword = nil
        self.hasSavedPassword = false
        try? FileManager.default.removeItem(at: vaultFileURL)
    }
}
