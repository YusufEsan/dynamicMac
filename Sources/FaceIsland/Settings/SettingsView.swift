import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Genel"
    case permissions = "İzinler"
    case faceID = "Face ID"
    case island = "Dinamik Ada"
    case audio = "Ses Karıştırıcı"
    case clipboard = "Pano Geçmişi"
    case switcher = "Pencere Yöneticisi"
    case security = "Güvenlik & Kasa"
    
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
    
    @State private var selectedTab: SettingsTab = .permissions
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
            .navigationSplitViewColumnWidth(min: 170, ideal: 200, max: 230)
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
            .frame(minWidth: 480, minHeight: 440)
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
            Section("Sistem & Başlangıç") {
                Toggle("Mac Başlangıcında Otomatik Başlat", isOn: $settings.launchAtLogin)
            }
            
            Section("İzin Özeti") {
                HStack {
                    Text("Tüm Sistem İzinlerini Yönet")
                    Spacer()
                    Button("İzinler Sayfasına Git...") {
                        selectedTab = .permissions
                    }
                }
            }
        }
    }
    
    // MARK: - Dedicated Permissions Tab
    private var permissionsSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sistem İzinleri (Permissions)")
                        .font(.title2.bold())
                    Text("FaceIsland'ın tüm özelliklerinin eksiksiz çalışabilmesi için gerekli sistem izinleri:")
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
                        description: "Face ID ile yüz tanıma ve ekran kilidini otomatik açmak için kullanılır.",
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
                        description: "Alt+Tab pencere değiştirici, fare tıklama geçirgenliği ve kısayollar için gereklidir.",
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
                        description: "Çentikte canlı video oynatıcı ve açık pencerelerin anlık önizlemeleri için gereklidir.",
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
                        description: "Dinamik Ada üzerinde yaklaşan etkinlikleri ve canlı geri sayımı gösterir.",
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
                .font(.system(size: 17))
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
            Section("Face ID Biyometri Profili") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(faceRecognition.isEnrolled ? "Face ID Profili Aktif" : "Kayıtlı Yüz Bulunamadı")
                            .font(.headline)
                        Text(faceRecognition.isEnrolled ? "FaceTime HD kamerasıyla eğitildi" : "Kilit açmak için yüzünüzü kaydedin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(faceRecognition.isEnrolled ? "Yeniden Eğit" : "Yüzü Tanıt") {
                        showEnrollmentSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Section("Eşleşme Hassasiyeti") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Yüz Eşleşme Güven Eşiği")
                        Spacer()
                        Text("%\(Int(settings.faceIDThreshold * 100))")
                            .bold()
                    }
                    Slider(value: $settings.faceIDThreshold, in: 0.60...0.95, step: 0.02)
                    Text("Yüksek değerler güvenliği artırır; düşük değerler loş ışıkta daha hızlı tanır.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Widget & Ekran Entegrasyonu") {
                Toggle("Face ID Widget Senkronizasyonu", isOn: $settings.isWidgetSyncEnabled)
                Text("Masaüstü ve kilit ekranı widget'ına anlık yüz tarama animasyonu ve durumunu iletir.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Dynamic Island Tab
    private var islandSettingsView: some View {
        Form {
            Section("Ada Görünüm Seçeneği") {
                Picker("Stil", selection: $settings.forceFloatingCapsule) {
                    Text("🏝️ Çentik Adası (Üste Yapışık)").tag(false)
                    Text("✨ Yüzen Kapsül (Ayrı / Taşınabilir)").tag(true)
                }
                .pickerStyle(.radioGroup)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Çentik Konumu (Hizalama)")
                            .font(.subheadline.bold())
                        Spacer()
                        if settings.forceFloatingCapsule {
                            Text("Sadece Çentik Adasında Aktif")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker("Konum", selection: $settings.notchAlignment) {
                        Text("⬅️ Sol").tag(NotchAlignment.left)
                        Text("⏺️ Orta").tag(NotchAlignment.center)
                        Text("➡️ Sağ").tag(NotchAlignment.right)
                    }
                    .pickerStyle(.segmented)
                    .disabled(settings.forceFloatingCapsule)
                    .opacity(settings.forceFloatingCapsule ? 0.45 : 1.0)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Text("Donanım Çentiği Algılandı")
                    Spacer()
                    Text(ScreenUtils.shared.hasNotch ? "Evet (MacBook Çentiği)" : "Hayır (Harici Monitör/Klasik)")
                        .foregroundColor(ScreenUtils.shared.hasNotch ? .green : .secondary)
                }
            }
            
            Section("Önizleme & İşlemler") {
                Button("Dinamik Adayı Genişlet / Kapat") {
                    IslandContentProvider.shared.toggleExpand()
                }
                
                Button("Yüzen Kapsülü Ekrana Getir") {
                    FloatingCapsuleController.shared.show()
                }
            }
        }
    }
    
    // MARK: - Audio Tab
    private var audioSettingsView: some View {
        Form {
            Section("Uygulama Ses Karıştırıcısı") {
                Text("FaceIsland çalışan medya oynatıcıları, tarayıcıları ve sesli uygulamaları otomatik algılar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Açık Ses Veren Uygulamaları Tara") {
                    AppAudioManager.shared.refreshActiveApps()
                }
            }
        }
    }
    
    // MARK: - Clipboard Tab
    private var clipboardSettingsView: some View {
        Form {
            Section("Geçmiş & Saklama Süresi") {
                Picker("Saklama Süresi", selection: $settings.clipboardRetentionDays) {
                    Text("1 Gün").tag(1)
                    Text("3 Gün").tag(3)
                    Text("7 Gün (Önerilen)").tag(7)
                    Text("14 Gün").tag(14)
                    Text("30 Gün").tag(30)
                }
                
                Text("Bu süreden eski kopyalanan veriler otomatik olarak temizlenir.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section("iCloud Eşzamanlama") {
                HStack {
                    Text("iCloud Pano Durumu")
                    Spacer()
                    Text("Devrede (Evrensel Pano)").foregroundColor(.green)
                }
                Text("iPhone ve Mac arasında kopyalanan metinleri senkronize eder.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Window Switcher Tab
    private var switcherSettingsView: some View {
        Form {
            Section("Alt + Tab Pencere Tablosu") {
                HStack {
                    Text("Aktivasyon Kısayolu")
                    Spacer()
                    HotkeyRecorderView(hotkeyString: $settings.switcherHotkey)
                }
                
                Button("Pencere Değiştiriciyi Önizle") {
                    WindowSwitcherController.shared.show()
                }
            }
        }
    }
    
    // MARK: - Security Tab
    private var securitySettingsView: some View {
        Form {
            Section("Otomatik Ekran Kilidi Açma") {
                Toggle("Ekran Uyanışında Face ID ile Mac Kilidini Aç", isOn: $settings.autoUnlockEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Oturum Açma Anahtarını Güvenli Anahtar Zincirinde (Keychain) Sakla")
                        .font(.subheadline)
                        .bold()
                    
                    SecureField("Mac Kullanıcı Şifresi", text: $unlockPasswordInput)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Anahtar Zincirine Kaydet") {
                            if !unlockPasswordInput.isEmpty {
                                let success = KeychainHelper.shared.savePassword(unlockPasswordInput)
                                passwordSaveStatus = success ? "AES-256 ile güvenle kaydedildi!" : "Kaydedilemedi"
                                unlockPasswordInput = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if KeychainHelper.shared.hasSavedPassword {
                            Button("Şifreyi Sil") {
                                KeychainHelper.shared.deletePassword()
                                passwordSaveStatus = "Şifre silindi."
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
