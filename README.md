# ClownDeck - DoctorRIDX Project

App Android (Flutter/Dart) untuk mengelola Sender WhatsApp dan mengirim file,
dengan backend Node.js (Baileys) yang berjalan sebagai server lokal di HP.

## Isi
- `lib/`, `pubspec.yaml`, `assets/` : app Flutter
- `.github/workflows/build.yml`    : build APK di GitHub Actions (hasil di tab Actions > Artifacts)
- `backend/backend.js`             : server lokal (API di 127.0.0.1:8787)

## Jalankan server
```bash
cd backend
npm install
node backend.js
```
Log pairing detail: `WA_LOG=debug node backend.js`
Folder yang dikirim: `Download/DokumenScript` (ganti dengan `CLOWNDECK_FOLDER=/path`).
