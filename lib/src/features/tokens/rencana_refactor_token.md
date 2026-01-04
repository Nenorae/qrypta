
---

# 🚀 MASTER PLAN BARU: Qrypta Wallet (Auto-Discovery)

## 1. Tujuan Utama

Menciptakan *User Experience* (UX) dompet digital yang **Instan ("Sat-set")** dan **Aman**. Pengguna tidak perlu tahu teknis "Contract Address". Mereka buka aplikasi, aset mereka langsung tampil.

## 2. Arsitektur Teknis

* **State Management:** `flutter_riverpod` (Untuk logic global) + `graphql_flutter` (Untuk data fetching).
* **Local Storage:**
* `flutter_secure_storage`: HANYA untuk Private Key & Mnemonic.
* `hive`: Untuk Cache GraphQL (Data Token, Saldo, Transaksi).
* `shared_preferences`: Hanya untuk settingan UI (Dark mode, Bahasa).


* **Network:** GraphQL Client dengan strategi `FetchPolicy.cacheAndNetwork`.

## 3. Rencana Implementasi (Roadmap)

### Fase 1: Fondasi Infrastruktur (Setup)

Fase ini menggantikan "Fase 1 Lama" yang menggunakan HTTP.

* [ ] **(Dependencies)** Update `pubspec.yaml`:
* Tambah: `hive`, `hive_flutter`, `cached_network_image`.
* Pastikan `graphql_flutter` versi terbaru.


* [ ] **(Core)** Setup Inisialisasi di `main.dart`:
* Inisialisasi Hive: `await Hive.initFlutter();`
* Setup `GraphQLClient` menggunakan `HiveStore()` (Bukan InMemory).
* Bungkus Root App dengan `ProviderScope` (Riverpod) dan `GraphQLProvider`.



### Fase 2: Data Layer & Logic (GraphQL)

Fokus pada pengambilan data otomatis. Tidak ada lagi logic "Add Manual".

* [ ] **(GraphQL)** Buat file query `lib/src/core/graphql/queries.dart`:
```graphql
query GetMyWallet($address: String!) {
  wallet(address: $address) {
    tokens {
      symbol
      name
      decimals
      balance
      logoUrl  # Server sudah menjamin ini aman & verified
    }
  }
}

```


* [ ] **(Repository)** Buat `WalletRepository` yang membungkus `GraphQLClient`.
* Fungsi utama bukan lagi `addToken()`, melainkan `watchWalletAssets()`.
* Menggunakan `client.watchQuery` agar data real-time (Stream).



### Fase 3: User Interface (Dashboard)

Fokus menampilkan data yang didapat dari Query.

* [ ] **(UI - Dashboard)** Hapus tombol "Tambah Token Manual" (atau sembunyikan di menu advanced).
* [ ] **(UI - Token List)** Implementasikan `Query` widget atau `StreamBuilder`:
* **Loading State:** Tampilkan Skeleton Loader / Shimmer.
* **Data State:** Render `ListView`.
* **Offline State:** Karena pakai Hive, data terakhir tetap muncul meski internet mati.


* [ ] **(UI - Image)** Ganti semua logika gambar lama dengan:
```dart
CachedNetworkImage(
  imageUrl: token.logoUrl,
  placeholder: (context, url) => Text(token.symbol[0]),
  errorWidget: (context, url, error) => AssetIcon('default_token.png'),
)

```



### Fase 4: Keamanan & Transaksi

* [ ] **(Security)** Audit penggunaan `flutter_secure_storage`. Pastikan Private Key tidak pernah dipanggil kecuali saat detik-detik penandatanganan transaksi.
* [ ] **(Transaction)** Implementasi pengiriman:
* Input Address & Amount.
* Sign Offline (`web3dart`).
* Kirim Hex via Mutation GraphQL.



---

## 4. Pedoman Pengembang (Do's & Don'ts)

Pegangan wajib agar kode tetap bersih dan performa terjaga sesuai arsitektur baru.

### ✅ DO (Lakukan)

1. **Gunakan `FetchPolicy.cacheAndNetwork`:** Untuk halaman Dashboard. Ini memberikan UX terbaik (Data lama muncul instan, data baru menyusul).
2. **Percaya pada Server untuk Gambar:** Jangan lakukan validasi hash di Flutter. Jika server mengirim URL logo, anggap itu valid. Tugas validasi ada di Backend Indexer.
3. **Gunakan `BigInt`:** Selalu parsing saldo token (`balance`) dari String ke `BigInt`. Jangan pakai `int` atau `double` agar presisi 18 desimal terjaga.
4. **Handle Null Logo:** Selalu siapkan *fallback* (gambar pengganti) jika `logoUrl` dari server bernilai `null` (belum terverifikasi).

### ❌ DON'T (Jangan Lakukan)

1. **JANGAN Simpan Data Token di SharedPreferences:** Itu arsitektur lama. Biarkan Hive dan GraphQL Cache yang mengurus persistensi data aset.
2. **JANGAN Input Address Manual:** Jangan paksa user mengetik `0x...` untuk melihat token mereka sendiri. Aplikasi harus pintar (Auto-Discovery).
3. **JANGAN Parsing JSON Manual:** Hindari `jsonDecode` manual. Gunakan hasil dari `graphql_flutter` atau gunakan generator seperti `ferry`/`artemis` untuk Type Safety.
4. **JANGAN Lakukan Heavy Lifting di UI:** Jangan generate wallet atau sign transaksi di dalam `build()` method widget. Pindahkan ke fungsi async terpisah atau Isolate.

---
