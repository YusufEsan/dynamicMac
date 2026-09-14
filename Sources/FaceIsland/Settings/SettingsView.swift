import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
    case faceID = "Face ID"
    case island = "Dynamic Island"
    case audio = "Audio"
    case clipboard = "Clipboard"
    case switcher = "Window Switcher"
    case security = "Security"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .permissions: return "hand.raised.badge.checkmark"
        case .faceID: return "faceid"
        case .island: return "oval.portrait"
        case .audio: return "speaker.wave.2"
        case .clipboard: return "doc.on.clipboard"
        case .switcher: return "macwindow.on.rectangle"
        case .security: return "lock.shield"
        }
    }
}

public struct SettingsView: View {
    @Bindable private var settings = SettingsManager.shared
    @Bindable private var faceRecognition = FaceRecognitionManager.shared
    private var permissions = PermissionManager.shared
    @Bindable private var clipboardManager = ClipboardManager.shared
    
    @State private var selectedTab: SettingsTab = .general
    @State private var showEnrollmentSheet = false
    @State private var unlockPasswordInput = ""
    @State private var passwordSaveStatus = ""
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 220)
        } detail: {
            Group {
                switch selectedTab {
                case .general:
                    generalSettingsView
                case .permissions:
                    permissionsSettingsView
                case .faceID:
                    faceIDSettingsView
                case .island:
                    islandSettingsView
                case .audio:
                    audioSettingsView
                case .clipboard:
                    clipboardSettingsView
                case .switcher:
                    switcherSettingsView
                case .security:
                    securitySettingsView
                }
            }
            .frame(minWidth: 460, minHeight: 400)
            .padding(24)
        }
        .sheet(isPresented: $showEnrollmentSheet) {
            EnrollmentView()
        }
        .onAppear {
            permissions.checkAll()
        }
    }
    
    // MARK: - General Tab
    private var generalSettingsView: some View {
        Form {
            Section("System & Startup") {
                Toggle("Launch FaceIsland at Login", isOn: $settings.launchAtLogin)
            }
            
            Section("Permissions Quick Overview") {
                HStack {
                    Text("System Permissions Status")
                    Spacer()
                    Button("Manage All Permissions...") {
                        selectedTab = .permissions
                    }
                }
            }
        }
    }
    
    // MARK: - Dedicated Permissions Tab
    private var permissionsSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sistem İzinleri (Permissions)")
                        .font(.title2.bold())
                    Text("FaceIsland'ın tüm özelliklerinin eksiksiz çalışması için gerekli sistem izinleri:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    permissions.checkAll()
                }) {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
            }
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    // 1. Camera
                    permissionRow(
                        title: "Kamera (FaceTime HD)",
                        description: "Face ID ile yüz tanıma ve otomatik kilit açma için kullanılır.",
                        icon: "camera.fill",
                        isGranted: permissions.cameraGranted,
                        onGrant: {
                            Task { _ = await permissions.requestCameraAccess() }
                        },
                        onOpenSettings: {
                            permissions.openSettings(for: .camera)
                        }
                    )
                    
                    // 2. Accessibility
                    permissionRow(
                        title: "Erişilebilirlik (Accessibility)",
                        description: "⌥+Tab pencere değiştirici ve klavye kısayolları için gereklidir.",
                        icon: "hand.raised.fill",
                        isGranted: permissions.accessibilityGranted,
                        onGrant: {
                            permissions.requestAccessibility()
                        },
                        onOpenSettings: {
                            permissions.openSettings(for: .accessibility)
                        }
                    )
                    
                    // 3. Screen Recording
                    permissionRow(
                        title: "Ekran Kaydı (Screen Recording)",
                        description: "Pencere değiştiricide açık pencerelerin canlı minyatür önizlemeleri için kullanılır.",
                        icon: "display",
                        isGranted: permissions.screenRecordingGranted,
                        onGrant: {
                            permissions.requestScreenRecording()
                        },
                        onOpenSettings: {
                            permissions.openSettings(for: .screenRecording)
                        }
                    )
                    
                    // 4. Calendar
                    permissionRow(
                        title: "Takvim Erişimi (Calendar)",
                        description: "Dinamik Ada üzerinde yaklaşan etkinlikleri ve geri sayımı gösterir.",
                        icon: "calendar",
                        isGranted: permissions.calendarGranted,
                        onGrant: {
                            Task { _ = await permissions.requestCalendarAccess() }
                        },
                        onOpenSettings: {
                            permissions.openSettings(for: .calendar)
                        }
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func permissionRow(
        title: String,
        description: String,
        icon: String,
        isGranted: Bool,
        onGrant: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 32, height: 32)
                .background((isGranted ? Color.green : Color.orange).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("İzin Verildi")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 8) {
                    Button("İzin Ver") {
                        onGrant()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .help("Sistem Ayarlarını Aç")
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Face ID Tab
    private var faceIDSettingsView: some View {
        Form {
            Section("Face Recognition Profile") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(faceRecognition.isEnrolled ? "Face ID Enrolled" : "No Face Enrolled")
                            .font(.headline)
                        Text(faceRecognition.isEnrolled ? "Trained on FaceTime HD camera" : "Set up your face to enable unlock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(faceRecognition.isEnrolled ? "Re-enroll Face" : "Enroll Face") {
                        showEnrollmentSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Section("Sensitivity & Matching") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Recognition Confidence Threshold")
                        Spacer()
                        Text("\(Int(settings.faceIDThreshold * 100))%")
                            .bold()
                    }
                    Slider(value: $settings.faceIDThreshold, in: 0.60...0.95, step: 0.02)
                    Text("Higher values increase security; lower values allow faster recognition in dim lighting.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Dynamic Island Tab
    private var islandSettingsView: some View {
        Form {
            Section("Display Style") {
                Toggle("Force Floating Capsule (Bypass Hardware Notch)", isOn: $settings.forceFloatingCapsule)
                
                HStack {
                    Text("Hardware Notch Detected")
                    Spacer()
                    Text(ScreenUtils.shared.hasNotch ? "Yes (MacBook Notch)" : "No (External/Legacy)")
                        .foregroundColor(ScreenUtils.shared.hasNotch ? .green : .secondary)
                }
            }
            
            Section("Preview & Actions") {
                Button("Toggle Island Expansion") {
                    IslandContentProvider.shared.toggleExpand()
                }
                
                Button("Bring Floating Capsule to Center") {
                    FloatingCapsuleController.shared.show()
                }
            }
        }
    }
    
    // MARK: - Audio Tab
    private var audioSettingsView: some View {
        Form {
            Section("Per-App Volume Controller") {
                Text("FaceIsland automatically detects running media players, browsers, and voice apps.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Scan Running Audio Apps Now") {
                    AppAudioManager.shared.refreshActiveApps()
                }
            }
        }
    }
    
    // MARK: - Clipboard Tab
    private var clipboardSettingsView: some View {
        Form {
            Section("History & Retention") {
                Picker("Retention Period", selection: $settings.clipboardRetentionDays) {
                    Text("1 Day").tag(1)
                    Text("3 Days").tag(3)
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                }
                
                Text("Items older than this limit (except pinned items) are automatically purged.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section("iCloud Sync") {
                HStack {
                    Text("iCloud Clipboard Status")
                    Spacer()
                    Text("Enabled (Universal)").foregroundColor(.green)
                }
                Text("Syncs clipboard between iPhone and Mac seamlessly without requiring a phone companion app.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Window Switcher Tab
    private var switcherSettingsView: some View {
        Form {
            Section("Alt + Tab Window Grid") {
                HStack {
                    Text("Activation Shortcut")
                    Spacer()
                    HotkeyRecorderView(hotkeyString: $settings.switcherHotkey)
                }
                
                Button("Preview Switcher Overlay") {
                    WindowSwitcherController.shared.show()
                }
            }
        }
    }
    
    // MARK: - Security Tab
    private var securitySettingsView: some View {
        Form {
            Section("Automatic Screen Unlock") {
                Toggle("Unlock Mac with Face ID on Screen Wake", isOn: $settings.autoUnlockEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Store Session Unlock Key in Secure Keychain")
                        .font(.subheadline)
                        .bold()
                    
                    SecureField("Mac User Password", text: $unlockPasswordInput)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Save to Keychain") {
                            if !unlockPasswordInput.isEmpty {
                                let success = KeychainHelper.shared.savePassword(unlockPasswordInput)
                                passwordSaveStatus = success ? "Saved securely in Keychain!" : "Failed to save"
                                unlockPasswordInput = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if KeychainHelper.shared.hasSavedPassword {
                            Button("Remove Password") {
                                KeychainHelper.shared.deletePassword()
                                passwordSaveStatus = "Password deleted."
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if !passwordSaveStatus.isEmpty {
                        Text(passwordSaveStatus)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}
