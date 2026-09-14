# 🏝️ FaceIsland (dynamicMac)

macOS için geliştirilmiş akıllı **Dinamik Ada (Dynamic Island)**, **Face ID ile Kilit Açma**, **Alt+Tab Pencere Yöneticisi** ve **Canlı Medya Kontrol Merkezi**.

---

## ⚙️ Gerekli İzinler ve Kurulum (Permissions & Setup)

Uygulamanın tüm özelliklerinin (kamera, medya, pencere geçişi, takvim) eksiksiz çalışabilmesi için aşağıdaki macOS ve tarayıcı izinlerinin verilmesi gerekmektedir:

### 1. 🌐 Google Chrome Canlı Video ve Medya İzni *(Önemli)*
Chrome'da izlenen YouTube, Netflix, dizi ve film sitelerindeki anlık video süresinin (`currentTime`), toplam sürenin ve oynatma durumunun adaya canlı aktarılması için:
- **Google Chrome**'u açın.
- Üst menü çubuğundan: **Görünüm** *(View)* > **Geliştirici** *(Developer)* > **Apple Etkinliklerinden JavaScript'e İzin Ver** *(Allow JavaScript from Apple Events)* seçeneğini işaretleyin.

---

### 2. 📷 Kamera İzni (Camera Permission)
Face ID yüz tanıma, yüz kaydetme ve kilit açma özelliğinin çalışması için:
- **Sistem Ayarları** *(System Settings)* > **Gizlilik ve Güvenlik** *(Privacy & Security)* > **Kamera** *(Camera)*
- Terminal veya `FaceIsland` uygulamasına kamera erişim izni verin.

---

### 3. ⌨️ Erişilebilirlik İzni (Accessibility Permission)
Alt+Tab gelişmiş pencere değiştirici, global fare tıklama geçişleri ve pencerelerin odaklanması için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Erişilebilirlik** *(Accessibility)*
- `FaceIsland` veya geliştirme ortamınıza (Terminal / VS Code / Cursor vb.) erişilebilirlik izni verin.

---

### 4. 🖥️ Ekran Kaydı İzni (Screen Recording Permission)
Alt+Tab arayüzünde çalışan açık pencerelerin anlık küçük önizleme görüntülerini ve simgelerini yakalamak için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Ekran Kaydı** *(Screen Recording)*
- `FaceIsland` uygulamasına ekran kaydı izni verin.

---

### 5. 📅 Takvim İzni (Calendar Permission)
Dinamik Ada üzerindeki Takvim sekmesinde yaklaşan etkinliklerin ve canlı geri sayımın görünmesi için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Takvimler** *(Calendars)*
- Uygulamaya tam takvim okuma erişimi sağlayın.

---

### 6. 🤖 Otomasyon & Apple Events (Automation Permission)
Spotify, Apple Music ve Google Chrome üzerinden parça değiştirme, duraklatma ve ses/zaman kontrolü için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Otomasyon** *(Automation)*
- `FaceIsland` altındaki **Google Chrome**, **Spotify** ve **Müzik** onay kutularını işaretleyin.

---

## 🚀 Projeyi Derleme ve Çalıştırma

Projeyi terminalden derlemek ve arka planda çalıştırmak için:

```bash
# Derleme
swift build

# Çalıştırma
swift run FaceIsland
```

---

## 🌟 Öne Çıkan Özellikler

- **Ada Stilleri**: Çentik Adası *(Notch Island)* ve Yüzen Kapsül *(Floating Capsule)* modları arasında dinamik geçiş.
- **Canlı Medya Takibi**: Spotify, Apple Music, YouTube ve tüm Chrome web video sitelerinden yüksek çözünürlüklü kapak resmi/favicon ve saniyelik zaman senkronizasyonu.
- **Gelişmiş Alt+Tab**: macOS yerleşik pencere yöneticisinden ilham alan simetrik, canlı önizlemeli pencere geçiş paneli.
- **Yerel Face ID**: Web kamerasını kullanarak kullanıcı yüzünü tanıma ve ekran kilidini otomatik açma.
- **Pano (Clipboard) Geçmişi**: Kopyalanan son metinleri saklayan ve hızlı erişim sunan tepsi modülü.
