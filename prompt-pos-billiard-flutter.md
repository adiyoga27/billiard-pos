# Prompt Coding: Aplikasi POS + Booking Meja Billiard (Flutter)

Gunakan prompt ini untuk memulai project di Claude Code, Cursor, atau AI coding assistant lainnya.

---

## 🎯 Ringkasan Project

Buatkan aplikasi Flutter multi-platform (Android, iOS, Tablet, Windows Desktop) untuk bisnis **Billiard Center** yang menggabungkan dua fungsi utama:

1. **Point of Sale (POS)** — untuk penjualan makanan, minuman, dan produk lain di kasir.
2. **Booking & Timer Meja Billiard** — untuk mengelola sewa meja billiard per jam secara real-time, mirip sistem rental PlayStation.

Kedua modul harus **terintegrasi**: tagihan sewa meja bisa digabung dengan pesanan makanan/minuman dalam satu struk.

---

## 🏗️ Tech Stack

- **Framework**: Flutter (target: Android, iOS, iPadOS/tablet, Windows desktop — gunakan layout responsif/adaptif, bukan aplikasi terpisah)
- **State Management**: Riverpod (gunakan `StreamProvider`/`AsyncNotifier` untuk data real-time dari Firestore seperti status meja & timer — cocok untuk arsitektur reaktif aplikasi ini)
- **Routing**: `go_router` — gunakan **named route dengan path parameter**, contoh:
  - `/transaction/:invoiceId` → detail transaksi (misal `/transaction/inv10002`)
  - `/table/:tableId` → detail sesi meja aktif
  - Ini penting untuk mendukung **deep link dari notifikasi**: saat notifikasi (Firebase Cloud Messaging) di-tap, payload notifikasi berisi path route (misal `/transaction/inv10002`), lalu app langsung `context.go(path)` ke halaman yang dimaksud tanpa perlu logic navigasi manual yang rumit
- **Backend & Database**: Firebase
  - **Cloud Firestore** sebagai database utama (NoSQL, document-based)
  - Gunakan **Firestore realtime listener (`snapshots()`)** untuk sinkronisasi status meja & timer antar device secara live
  - **Firebase Authentication** untuk login & role-based access (Admin, Kasir) — role disimpan di custom claims atau di collection `users`
  - **Firebase Storage** untuk gambar produk
  - **Cloud Functions** (opsional, tahap lanjutan) untuk logic sensitif seperti finalisasi perhitungan biaya meja atau validasi transaksi, supaya tidak bisa dimanipulasi dari client
- **Local caching**: Firestore sudah punya offline persistence bawaan (`enablePersistence`), manfaatkan ini untuk mode offline sementara saat koneksi putus
- **Printer**: Integrasi cetak struk ke thermal printer (ESC/POS) via Bluetooth/USB (gunakan package seperti `esc_pos_bluetooth` / `esc_pos_utils`)
- **Alarm & Notifikasi**: `audioplayers` untuk alarm suara in-app real-time, `firebase_messaging` + `flutter_local_notifications` untuk push notification (termasuk saat app di background/terminated)

---

## 📦 Modul & Fitur Detail

### 1. Autentikasi & Role
- Login dengan email/password via Supabase Auth
- Role: **Admin** (akses penuh) dan **Kasir** (akses terbatas ke transaksi harian)
- Admin bisa membuat akun kasir baru dan mengatur permission

### 2. Modul Manajemen Meja Billiard
- Daftar meja (nama/nomor meja, tipe meja jika ada lebih dari satu jenis, tarif per jam)
- Status meja real-time: **Kosong**, **Terpakai**, **Reserved**
- Saat meja mulai dipakai:
  - Tekan "Mulai" → timer berjalan real-time (jam:menit:detik)
  - Biaya berjalan otomatis dihitung berdasarkan tarif per jam (bisa pembulatan per menit atau per blok waktu — buat konfigurasinya)
  - Tampilkan estimasi biaya berjalan secara live di kartu meja
- Saat "Selesai" ditekan:
  - Timer berhenti, biaya final dihitung
  - Bisa langsung digabung ke transaksi POS (tambah pesanan makanan/minuman) sebelum checkout
- Riwayat penggunaan per meja (durasi, biaya, waktu mulai-selesai, kasir yang menangani)
- Sinkronisasi status meja real-time ke semua device yang login (pakai Firestore realtime listener)

#### 2a. Sub-fitur: Sesi dengan Target Durasi & Peringatan Waktu Habis

- Saat memulai sesi, kasir memilih salah satu mode:
  - **Tanpa batas waktu** — sesi berjalan bebas, biaya dihitung dari total durasi aktual saat "Selesai" ditekan (perilaku default/lama).
  - **Set durasi** — kasir input target durasi (misal 1 jam, 2 jam), sistem menyimpan `waktu_selesai_target = waktu_mulai + durasi`.
- **Ambang peringatan** (default 10 menit sebelum habis, bisa diubah di Pengaturan Admin) — saat sisa waktu sesi mencapai ambang ini:
  - Tampilkan **dialog interaktif** di layar kasir: *"Meja [X] akan selesai dalam [N] menit"* dengan dua pilihan aksi: **Perpanjang Waktu** (input tambahan durasi) atau **Selesaikan Sekarang**
  - Putar **alarm suara** untuk menarik perhatian kasir (gunakan `audioplayers`, suara berulang/looping sampai direspons atau dialog ditutup)
  - Kirim **push notification** (Firebase Cloud Messaging) sebagai lapisan kedua, terutama untuk device staff lain yang mungkin tidak sedang membuka app — payload notifikasi menyertakan route (`/table/:tableId`) agar bisa langsung deep-link ke meja terkait
- Jika waktu benar-benar habis **tanpa direspons**: status meja **TIDAK otomatis berubah jadi "kosong"** — tetap "terpakai" tapi diberi indikator visual berbeda (misal border merah berkedip / badge "Waktu Habis") sampai kasir mengambil aksi manual. Ini mencegah kerugian bisnis akibat sesi dianggap selesai padahal masih dipakai.
- **Sumber kebenaran waktu** (`waktu_selesai_target`) disimpan di Firestore, bukan hanya di memori lokal device — supaya perhitungan sisa waktu tetap akurat meski app di-restart, device kasir berganti, atau koneksi sempat putus dan tersambung lagi.
- Pertimbangkan **Cloud Function terjadwal** (Cloud Scheduler + Cloud Function, jalan tiap 1 menit) yang mengecek sesi-sesi mendekati `waktu_selesai_target` dan mengirim FCM notification dari sisi server — ini lebih reliable dibanding murni client-side timer, karena tetap terkirim meski app kasir sedang tidak aktif/di-reload.
- Field tambahan di `table_sessions`: `mode: 'bebas' | 'durasi_tetap'`, `waktu_selesai_target (nullable)`, `is_alert_triggered (boolean, mencegah alert dobel)`, `durasi_perpanjangan_menit (array log riwayat perpanjangan)`

#### 2b. Sub-fitur: Paket Main Billiard

- Selain tarif normal per jam, kasir bisa memilih **paket** saat memulai sesi. Dua tipe paket:
  - **Paket durasi flat** — durasi & harga sudah ditentukan (misal "Paket 2 Jam — Rp 50.000"). Saat dipilih, sesi otomatis masuk mode `durasi_tetap` dengan `waktu_selesai_target` terhitung otomatis, dan biaya sudah fixed (tidak dihitung ulang per menit dari tarif normal).
  - **Paket tarif khusus per jam** — override tarif per jam normal untuk kondisi tertentu (misal "Paket Weekday" atau "Paket Member" dengan tarif lebih murah), tapi durasi tetap bebas seperti mode biasa.
- Setiap paket punya syarat berlaku (opsional): hari aktif (misal hanya Senin–Jumat), jam berlaku (misal hanya sebelum jam 17:00), dan bisa dibatasi hanya untuk meja tertentu.
- Admin mengelola daftar paket lewat Modul Pengaturan (aktifkan/nonaktifkan paket, atur harga & syarat).
- Field baru di `table_sessions`: `package_id (nullable)` — jika null berarti pakai tarif normal.

#### 2c. Sub-fitur: Diskon & Biaya Tambahan Dinamis pada Sesi Meja

- **Diskon sesi meja** — sama seperti diskon di POS (persentase atau nominal), tapi diterapkan ke biaya sewa meja. Berguna untuk diskon member atau promo khusus. Field: `diskon: { tipe: 'persen' | 'nominal', nilai, alasan (opsional, misal kode promo) }`
- **Biaya tambahan dinamis** — daftar biaya ad-hoc yang bisa ditambahkan kasir/admin **kapan saja selama sesi masih berjalan**, di luar katalog produk POS biasa. Contoh: sewa stik premium, ganti bola, biaya kerusakan, extra time di luar paket.
  - Field: `biaya_tambahan: [ { nama, jumlah, harga_satuan, subtotal, ditambahkan_oleh (kasir_id), waktu_ditambahkan } ]`
  - Setiap item ini otomatis masuk ke breakdown tagihan akhir sesi, terpisah dari biaya sewa waktu dan dari item POS (makanan/minuman), supaya laporan tetap rapi per kategori.
- Breakdown tagihan akhir sesi meja jadi: `biaya sewa waktu (atau harga paket flat) + total biaya tambahan − diskon = subtotal sesi meja`, yang kemudian bisa digabung lagi dengan item POS (makanan/minuman) sesuai keputusan desain di modul POS.

### 3. Modul POS (Point of Sale)

> **Keputusan desain penting**: transaksi makan/minum **TIDAK wajib** terikat ke meja billiard. Field relasi ke meja bersifat **opsional (nullable)**. Kasir harus bisa memilih salah satu alur berikut saat membuat transaksi:
> - **Gabung ke meja tertentu** — item ditambahkan ke tagihan berjalan meja yang sedang aktif, dibayar sekaligus saat sesi selesai.
> - **Transaksi tanpa meja (walk-in/counter sale)** — pelanggan beli langsung tanpa main billiard, dibayar saat itu juga di kasir.
> - **Ada meja tapi bayar terpisah** — item dibayar langsung di kasir meski pelanggan sedang main (opsional, sesuaikan dengan SOP tempat usaha).
>
> Jangan memaksa setiap transaksi harus punya `table_session_id`, karena akan merusak akurasi laporan penjualan counter biasa.

- Manajemen produk: nama, kategori, harga, stok, gambar
- Manajemen kategori produk (makanan, minuman, snack, dll)
- Manajemen stok/inventory (kurangi otomatis saat terjual, alert stok menipis)
- Keranjang transaksi (tambah/kurang qty, hapus item)
- Diskon: per item atau per transaksi (persentase atau nominal) — gunakan struktur diskon yang **konsisten** dengan diskon di sesi meja billiard (lihat sub-fitur 2c), supaya logic perhitungan diskon tidak duplikat/berbeda antara dua modul
- Pajak/service charge (opsional, bisa di-nonaktifkan)
- Metode pembayaran: Tunai, QRIS, Kartu (catat manual dulu, integrasi payment gateway jadi tahap lanjutan/opsional)
- Cetak struk ke thermal printer setelah transaksi
- Gabungkan tagihan meja billiard + pesanan makanan/minuman dalam satu struk

### 4. Modul Laporan (Reporting)
- Laporan penjualan harian/mingguan/bulanan (grafik + tabel)
- Laporan pendapatan per meja billiard (jam sibuk, total pemakaian)
- Laporan produk terlaris
- Filter berdasarkan rentang tanggal dan kasir
- Export laporan ke PDF/Excel (opsional tahap lanjutan)

### 5. Modul Pengaturan (Admin only)
- Atur tarif per jam per meja
- Atur metode pembulatan waktu (per menit / per 15 menit / per jam penuh)
- Atur **ambang waktu peringatan sesi durasi tetap** (default 10 menit sebelum habis, bisa disesuaikan per kebutuhan)
- **Kelola paket main billiard** — tambah/edit/nonaktifkan paket, atur tipe (durasi flat / tarif khusus), harga, syarat berlaku (hari, jam, meja tertentu)
- Atur pajak & service charge
- Kelola akun kasir & role
- Setup printer (pilih device Bluetooth/USB)

---

## 📱 Kebutuhan UI/UX

- **Responsif & adaptif**: layout menyesuaikan otomatis antara mobile (portrait, 1 kolom), tablet (2 kolom, ideal untuk kasir), dan Windows desktop (layout lebar dengan sidebar navigasi)
- Dashboard utama menampilkan: ringkasan status semua meja (grid card) + shortcut ke POS
- Desain bersih, mudah dibaca dari jarak agak jauh (karena dipakai kasir yang sering standing/bergerak)
- Warna status meja jelas: hijau (kosong), merah (terpakai), kuning (reserved)
- Real-time update tanpa perlu refresh manual

---

## 🗂️ Struktur Database (Firestore) — Usulan Koleksi

Model data NoSQL, disesuaikan agar query real-time efisien:

- **`users`** (doc id = uid dari Firebase Auth)
  `{ nama, email, role: 'admin' | 'kasir' }`

- **`tables`**
  `{ nama_meja, tarif_per_jam, status: 'kosong' | 'terpakai' | 'reserved', metode_pembulatan, current_session_id (nullable) }`
  → field `status` dan `current_session_id` inilah yang di-listen real-time oleh semua device untuk update dashboard meja.

- **`table_sessions`** (subcollection dari `tables/{tableId}/sessions` ATAU koleksi top-level dengan field `table_id` — pilih top-level jika butuh query lintas meja untuk laporan)
  `{ table_id, waktu_mulai, waktu_selesai (nullable), durasi_menit, biaya, kasir_id, status: 'berjalan' | 'selesai', mode: 'bebas' | 'durasi_tetap', waktu_selesai_target (nullable), is_alert_triggered (boolean), riwayat_perpanjangan: [...], package_id (nullable), diskon: { tipe, nilai, alasan } (nullable), biaya_tambahan: [ { nama, jumlah, harga_satuan, subtotal, ditambahkan_oleh, waktu_ditambahkan } ] }`

- **`packages`**
  `{ nama_paket, tipe: 'durasi_flat' | 'tarif_khusus', durasi_menit (nullable, wajib jika durasi_flat), harga (harga flat jika durasi_flat, atau tarif per jam jika tarif_khusus), hari_aktif (array, opsional), jam_mulai_berlaku (opsional), jam_selesai_berlaku (opsional), berlaku_untuk_meja (array table_id, opsional — kosong berarti semua meja), is_active (boolean) }`

- **`products`**
  `{ nama, kategori_id, harga, stok, gambar_url }`

- **`categories`**
  `{ nama }`

- **`transactions`**
  `{ kasir_id, table_session_id (NULLABLE — lihat catatan desain di modul POS), subtotal, diskon, pajak, total, metode_bayar, created_at, items: [ { product_id, nama, qty, harga_satuan, subtotal } ] }`
  → Item transaksi disimpan sebagai **array embedded** di dalam dokumen transaksi (bukan subcollection terpisah), karena jarang di-query terpisah dan lebih efisien dibaca sekaligus — sesuai best practice Firestore untuk data yang selalu dibaca bersama.

**Catatan indexing**: buat composite index di Firestore untuk query laporan (misal filter `created_at` + `kasir_id`, atau `table_id` + `status`), karena Firestore butuh index eksplisit untuk query gabungan.

---

## ✅ Prioritas Pengembangan (Bertahap)

1. Setup project Flutter + koneksi Supabase + Auth & role
2. Modul Manajemen Meja + Timer real-time (fitur inti/pembeda utama)
3. Modul POS dasar (produk, kategori, transaksi, checkout)
4. Integrasi tagihan meja + POS jadi satu struk
5. Cetak struk thermal printer
6. Modul laporan & dashboard
7. Modul pengaturan admin
8. Optimasi layout untuk Windows desktop & tablet
9. (Opsional) Mode offline dengan local caching

---

## 📌 Catatan Tambahan untuk AI Coding Assistant

- Tulis kode dengan struktur folder yang rapi (feature-based folder structure, bukan layer-based) agar mudah di-maintain
- Sertakan komentar pada logic perhitungan biaya berjalan (timer → biaya), karena ini bagian paling krusial dan rawan bug
- Buat perhitungan biaya berjalan sebagai pure function yang mudah di-unit test
- Pastikan penanganan race condition saat dua device mencoba mengubah status meja yang sama secara bersamaan — gunakan Firestore **transaction** (`runTransaction`) saat update status meja, jangan sekadar `set`/`update` biasa
- Tulis **Firestore Security Rules** yang membatasi akses berdasarkan role (misal: hanya admin yang boleh ubah tarif meja atau hapus produk; kasir hanya boleh baca produk & buat transaksi)
- Gunakan file konfigurasi Firebase resmi (`firebase_options.dart` hasil `flutterfire configure`), jangan hardcode API key secara manual
- Implementasikan **Firebase Cloud Messaging (FCM)** untuk notifikasi (misal: notifikasi ke kasir saat waktu sewa meja hampir habis, atau notifikasi transaksi baru ke admin). Payload notifikasi harus menyertakan path route tujuan (contoh: `{"route": "/transaction/inv10002"}`) agar bisa langsung dipakai oleh go_router untuk navigasi otomatis saat notifikasi di-tap (baik dari kondisi foreground, background, maupun app terminated)
- Definisikan semua route di satu tempat terpusat (`app_router.dart`) menggunakan `GoRouter` dengan named path parameter, jangan pakai `Navigator.push` manual tanpa nama route, supaya konsisten dan mudah di-trace saat debugging deep link
