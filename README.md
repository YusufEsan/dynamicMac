# 🏝️ FaceIsland (dynamicMac)

macOS için tasarlanmış yüksek performanslı, akıllı **Dinamik Ada (Dynamic Island)**, **Face ID ile Otomatik Kilit Açma**, **Uygulama Ses Karıştırıcısı (Audio Mixer)**, **Akıllı Pano Geçmişi (Clipboard Manager)** ve **Gelişmiş Alt+Tab Pencere Yöneticisi**.

---

## 🌟 Öne Çıkan Özellikler

- **Dinamik Ada & Çentik Entegrasyonu:**
  - Çentikli MacBook'lar için yerleşik çentik (`Notch Island`) veya harici ekranlar/çentiksiz modeller için serbest `Yüzen Kapsül (Floating Capsule)` modu.
  - **Piksel Hassasiyetinde Fare Geçirgenliği (Mouse Passthrough):** Ada açıkken veya kapalıyken çentik etrafındaki web butonlarına (ör. çerez onayları, menüler) tıklamayı engellemez.

- **🎛️ Uygulama Ses Karıştırıcısı (App Volume Mixer):**
  - Arka planda ses çalan tüm uygulamaları (Google Chrome, Arc, Brave, Safari, Spotify, Apple Music, VLC vb.) otomatik tespit eder.
  - Her uygulamanın ses seviyesini adadan bağımsız olarak kısma/açma ve sessize alma imkânı.
  - 5 uygulamaya kadar dinamik sıralama, fazlası için pürüzsüz kaydırma (scroll).

- **🎵 Canlı Medya ve Ekolayzır (Media Center):**
  - Spotify, Apple Music ve YouTube (Chrome) için anlık şarkı/video başlığı, sanatçı ve yüksek çözünürlüklü kapak görseli.
  - Platforma özel dinamik renkler: Spotify için yeşil (`#1CD661`), YouTube için kırmızı (`#FF2626`), Apple Music için logo kırmızısı (`#FA2D48`).
  - Anlık video/şarkı ilerleme çubuğu (`currentTime` / `duration`) ve duraklat/oynat/atla kontrolleri.

- **📋 Akıllı Pano Yöneticisi (Clipboard Manager):**
  - Kopyalanan son metin ve içerikleri saklar.
  - Kopyalanan verinin uzunluğuna göre dinamik genişleyen ve dikeyde en fazla 2 blok büyüyen, ardından kaydırılabilen (scroll) akıllı kart yapısı.
  - Tek tıkla panoya geri alma veya geçmişi temizleme.

- **👤 Yerel Face ID ile Ekran Kilidi Açma (Auto Unlock):**
  - Mac ekranı uyandığında web kamerası üzerinden yüz tanıma yaparak ekran kilidini otomatik açar.
  - Yerel Apple Vision Framework kullanımı sayesinde veriler cihaz dışına çıkmaz.

- **🪟 Gelişmiş Alt+Tab Pencere Yöneticisi:**
  - macOS yerleşik pencere değiştiricisinden ilham alan, açık pencerelerin anlık küçük önizlemelerini ve simgelerini gösteren hızlı geçiş paneli.

---

## ⚙️ Gerekli İzinler ve Kurulum (Permissions & Setup)

Uygulamanın tüm özelliklerinin eksiksiz çalışabilmesi için aşağıdaki macOS ve tarayıcı izinlerinin verilmesi gerekmektedir:

### 1. 🌐 Google Chrome Canlı Video & Ses İzni *(Önemli)*
Chrome'da izlenen YouTube, Netflix ve web videolarının adaya canlı aktarılması ve ses kontrolü için:
- **Google Chrome**'u açın.
- Üst menü çubuğundan: **Görünüm (View)** > **Geliştirici (Developer)** > **Apple Etkinliklerinden JavaScript'e İzin Ver (Allow JavaScript from Apple Events)** seçeneğini işaretleyin.

---

### 2. 📷 Kamera İzni (Camera Permission)
Face ID yüz tanıma, yüz kaydetme ve kilit açma özelliğinin çalışması için:
- **Sistem Ayarları (System Settings)** > **Gizlilik ve Güvenlik (Privacy & Security)** > **Kamera (Camera)**
- `FaceIsland` veya Terminal ortamınıza kamera erişim izni verin.

---

### 3. ⌨️ Erişilebilirlik İzni (Accessibility Permission)
Gelişmiş Alt+Tab pencere geçişleri, global tıklama geçirgenliği ve pencerelerin odaklanması için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Erişilebilirlik (Accessibility)**
- `FaceIsland` uygulamasına erişilebilirlik izni verin.

---

### 4. 🖥️ Ekran Kaydı İzni (Screen Recording Permission)
Alt+Tab arayüzünde pencerelerin anlık küçük önizleme görüntülerini yakalamak için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Ekran Kaydı (Screen Recording)**
- `FaceIsland` uygulamasına izin verin.

---

### 5. 🤖 Otomasyon & Apple Events (Automation Permission)
Spotify, Apple Music ve tarayıcılar üzerinden ses/zaman kontrolü için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Otomasyon (Automation)**
- `FaceIsland` altındaki **Google Chrome**, **Spotify** ve **Müzik** onay kutularını işaretleyin.

---

### 6. 📅 Takvim İzni (Calendar Permission)
Ada üzerinde yaklaşan takvim etkinliklerinin ve geri sayımın görünmesi için:
- **Sistem Ayarları** > **Gizlilik ve Güvenlik** > **Takvimler (Calendars)**
- Uygulamaya takvim okuma izni verin.

---

## 🚀 Projeyi Derleme ve Çalıştırma

Projeyi terminal üzerinden doğrudan derleyip çalıştırmak için:

```bash
# Projeyi derleme
swift build

# Uygulamayı başlatma
swift run FaceIsland
```

---

## 🛠️ Mimari ve Teknolojiler

- **Dil / Çatı:** Swift 6, SwiftUI, AppKit
- **Biyometri & Görüntü İşleme:** Apple Vision Framework, AVFoundation
- **Pencere & Katman Yönetimi:** CoreGraphics, NSPanel (`canJoinAllSpaces`, `fullScreenAuxiliary`)
- **Sistem & Medya Otomasyonu:** AppleScript / NSAppleScript, CoreAudio, DistributedNotificationCenter
