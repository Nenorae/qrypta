# Dokumentasi Teknis Qrypta & Bali Tourist ID

Direktori ini memuat seluruh dokumentasi arsitektur sistem, spesifikasi protokol kriptografi, blueprint integrasi, serta analisis teknis mendalam per modul kode.

---

## 1. Arsitektur Sistem & Spesifikasi Ekosistem (`docs/architecture/`)

Dokumentasi tingkat sistem untuk integrasi ekosistem Bali Tourist ID dan fondasi Web3 Qrypta:

| Dokumen | Deskripsi Teknis |
| :--- | :--- |
| [Tourist App (Path 1)](architecture/BEDAH_TEKNIS_BALI_TOURIST_ID_PATH1_TURIS_APP.md) | Dekonstruksi alur aplikasi turis, pemindaian ICAO Doc 9303 MRZ, ePassport NFC (BAC/PACE), dynamic rotating QR (45s), dan selective disclosure. |
| [Merchant App](architecture/BEDAH_TEKNIS_BALI_TOURIST_ID_MERCHANT_APP.md) | Arsitektur Relying Party, zero-photocopy engine, template izin berbasis tujuan, integrasi perhotelan (PMS), rental kendaraan, dan age gate. |
| [Government Portal](architecture/BEDAH_TEKNIS_BALI_TOURIST_ID_GOVERNMENT_PORTAL.md) | Trust Anchor, Policy Engine, ledger penerimaan Tourist Levy, registri wisatawan & protokol reveal izin hukum, immutable audit trail. |
| [Comprehensive Technical Analysis V1](architecture/comprehensive_technical_analysis.md) | Konsolidasi arsitektur Clean Architecture, standar kurva secp256k1, HD Wallet BIP-32/BIP-44, dan optimasi background Isolate. |
| [Comprehensive Technical Analysis V2](architecture/comprehensive_technical_analysis_V2.md) | Arsitektur komprehensif lanjutan yang mencakup integrasi likuiditas lintas batas (Cross-Border QRIS) dan bridge fiat-kripto. |
| [Rencana Pengerjaan Qrypta x ezsign-core](architecture/rencana_pengerjaan_qryptaXezsigncore.md) | Blueprint eksekusi integrasi Flutter Qrypta dengan backend middleware ezsign-core, RabbitMQ, tx-worker, dan node Hyperledger Besu. |

---

## 2. Analisis Modul & Kode Sumber (`docs/modules/`)

Dokumentasi audit dan spesifikasi teknis untuk setiap lapisan internal aplikasi (`lib/src/`):

### A. Core Infrastructure
- [Core Architecture Analysis](modules/core_analysis.md): Analisis mendalam `lib/src/core/`, spesifikasi Web3 JSON-RPC, indexer GraphQL, Hive cache, dan audit utang teknis.
- [Core Services Summary](modules/core_services_summary.md): Ringkasan arsitektur service layer (local authentication & gateway blockchain).

### B. Fitur Aplikasi (`lib/src/features/`)
- [Features Overview](modules/features_overview.md): Dekonstruksi menyeluruh arsitektur lintas fitur, dependensi provider, dan evaluasi celah keamanan.
- [Authentication Technical Analysis](modules/auth_technical_analysis.md): Arsitektur Clean Architecture auth, use cases, secure storage, dan state notifier.
- [Authentication Keypair Explanation](modules/auth_keypair_explanation.md): Rincian teknis standar BIP-39, master seed derivation `m/44'/60'/0'/0/0`, dan kompatibilitas Besu/EVM.
- [Home Dashboard Analysis](modules/home_analysis.md): Analisis komponen UI dashboard, status data statis vs dinamis.
- [Home Renovation Plan](modules/home_renovation_plan.md): Rencana migrasi dashboard menjadi full reactive on-chain source of truth.
- [Profile & Settings Analysis](modules/profile_technical_analysis.md): Modular grouping, auto-lock state, dan hardware biometric gatekeeper untuk reveal secrets.
- [Tokens Feature Analysis](modules/tokens_analysis.md): Strategi aset terverifikasi Rupiah Token (IDRT), konfigurasi `.env`, dan verifikasi saldo hybrid RPC.
- [Tokens IDRT Refactor Plan](modules/tokens_rencana_refactor_idrt.md): Rencana teknis pembersihan token discovery dinamis menuju model IDRT terkurasi.
- [Transaction Feature Analysis](modules/transaction_analysis.md): Siklus hidup transaksi on-chain, offline signing, broadcast, dan polling receipt.
