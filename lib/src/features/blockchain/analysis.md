# Analisis Perbandingan: `features/blockchain` vs `core/services/blockchain`

Dokumen ini membandingkan dua implementasi `BlockchainService` yang ada di dalam codebase untuk menentukan hubungan keduanya: apakah saling melengkapi atau bertabrakan.

## Kesimpulan Awal: Bertabrakan Secara Fundamental

Berbeda dengan kasus `send_money` dan `transaction`, kedua direktori ini **saling bertabrakan**. Struktur yang ada di `lib/src/core/services/blockchain/` adalah versi **refactor** yang modern dan superior, yang dirancang untuk menggantikan implementasi lama yang ada di `lib/src/features/blockchain/services/blockchain_service.dart`.

Implementasi lama di `features` harus dianggap sebagai **kode usang (deprecated)** yang belum dihapus.

### Analogi: Rumah Tua vs. Rumah Modern

-   **`features/blockchain/services/blockchain_service.dart` (Rumah Tua):**
    Ini adalah sebuah rumah dengan satu ruangan raksasa (disebut "God Class"). Di dalamnya, dapur, kamar tidur, ruang kerja, dan garasi semuanya menjadi satu. Fungsional, tetapi sangat berantakan, sulit untuk merawat atau merenovasi satu bagian tanpa mengganggu bagian lain.

-   **`core/services/blockchain/` (Rumah Modern):**
    Ini adalah rumah yang dirancang dengan baik. Ada "Ruang Utama" (`blockchain_service.dart`) yang berfungsi sebagai gerbang, dan dari sana ada pintu ke ruangan-ruangan spesialis:
    -   Kamar "Dapur Native" (`native_currency_service.dart`)
    -   Kamar "Perkakas Token ERC20" (`erc20_service.dart`)
    -   Kamar "Arsip & Pengiriman" (`transaction_service.dart`)
    -   Kamar "Keamanan Dompet" (`wallet_service.dart`)
    Setiap ruangan memiliki fungsi yang jelas, terisolasi, dan mudah dirawat.

---

## Tabel Perbandingan Rinci

| Kriteria | `features/blockchain/services` (Lama) | `core/services/blockchain` (Baru) | Penjelasan |
| :--- | :--- | :--- | :--- |
| **Arsitektur & Struktur** | **Monolitik** | **Modular (Gateway & Sub-Service)** | Versi lama menumpuk semua fungsi (native, ERC20, wallet) dalam satu file. Versi baru memecahnya menjadi file-file kecil yang bertanggung jawab atas satu hal (Prinsip SRP). |
| **Prinsip Desain (SRP)**| **Sangat Melanggar**. Satu kelas melakukan terlalu banyak hal. | **Sangat Menerapkan**. Setiap `service` memiliki satu tanggung jawab yang jelas, membuatnya mudah dikelola dan dimodifikasi. | Desain baru jauh lebih bersih dan skalabel. Jika ada perubahan pada logika ERC20, kita hanya perlu menyentuh `erc20_service.dart`. |
| **Pengambilan Data** | **Murni RPC (Remote Procedure Call)** | **Hibrida (GraphQL + RPC)** | Versi lama mengambil semua data (termasuk riwayat transaksi) langsung dari node. Versi baru lebih pintar: menggunakan **GraphQL** untuk mengambil data yang sudah diindeks (seperti riwayat) dan hanya menggunakan **RPC** untuk aksi yang harus langsung ke node (seperti mengambil receipt). |
| **Keterbacaan & Perawatan**| **Sulit**. File yang sangat panjang (>200 baris) sulit dinavigasi dan dipahami. | **Mudah**. File-file kecil dan terfokus lebih mudah dibaca, dipahami, dan dirawat. | Jelas bahwa tim telah melakukan refactor untuk meningkatkan kualitas kode. |
| **Testability (Kemudahan Tes)** | **Sulit**. Service ini membuat instance `Web3Client` sendiri, sehingga sulit untuk melakukan *mocking* saat unit testing. | **Mudah**. Menggunakan **Dependency Injection** melalui Riverpod. `Web3Client` dan `GraphQLClient` "disuntikkan" ke dalam service, sehingga saat testing kita bisa menyuntikkan *mock client*. | Desain baru memungkinkan pengujian yang lebih andal dan terisolasi. |

## Putusan Akhir

Implementasi `BlockchainService` di `lib/src/features/blockchain/services/` adalah **warisan teknis (technical debt)** yang harus **dihindari** penggunaannya. Ia secara fungsional telah digantikan sepenuhnya oleh arsitektur yang lebih unggul di `lib/src/core/services/blockchain/`.

### Rekomendasi

1.  **Hentikan Penggunaan:** Semua kode baru **wajib** menggunakan provider `blockchainServiceProvider` yang diekspor dari `lib/src/core/services/blockchain/blockchain_service.dart`.
2.  **Refactor Kode Lama:** Kode yang masih mengimpor atau menggunakan `BlockchainService` dari direktori `features` harus segera di-refactor untuk menggunakan versi `core`.
3.  **Hapus File Lama:** Setelah semua dependensi ke file lama telah dihilangkan, file `lib/src/features/blockchain/services/blockchain_service.dart` harus **dihapus** dari proyek untuk mencegah kebingungan dan bug di masa depan.
