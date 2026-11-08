# ClownDeck — DoctorRIDX Project

Base aplikasi Android (Flutter + Dart). Tema neo-brutalism gelap, merah & abu-abu.

## Struktur
- `lib/main.dart` — entry point
- `lib/core/theme.dart` — warna & tema
- `lib/core/features.dart` — **daftar fitur (tambah fitur di sini)**
- `lib/screens/dashboard_screen.dart` — dashboard + banner
- `lib/widgets/` — komponen neo-brutalism (`BrutalBox`, `FeatureTile`)
- `assets/images/` — `icon.png`, `banner.jpg`
- `android_res/` — ikon adaptive (dipasang otomatis oleh workflow)
- `.github/workflows/build-apk.yml` — build APK otomatis

## Build
Push ke GitHub (branch `main`) → tab **Actions** → download artifact **ClownDeck-APK**.
Push tag `v*` (contoh `v1.0.0`) → APK juga masuk ke **Releases**.

Workflow selalu pakai Flutter **stable terbaru**, membuat folder `android/` dari template terbaru,
lalu menjalankan `flutter pub upgrade --major-versions`.

## Push via Termux
```bash
unzip ClownDeck.zip && cd ClownDeck
git init && git branch -M main
git add . && git commit -m "ClownDeck base"
git remote add origin https://github.com/DoctorRIDX/ClownDeck.git
git push -u origin main
```
