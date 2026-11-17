# INVENTARISASI BLOK CATCH & AUDIT INTEGRITAS KODE (PHASE 0)
**Proyek:** Qrypta & Bali Tourist ID
**Tanggal:** 17 November 2026
**Branch:** `fix/real-behavior`

---

## 1. RINGKASAN EKSEKUTIF INVENTARIS CATCH

- **Total blok `catch` ditemukan di `lib/`:** 94
  - `MENELAN_ERROR (FALLBACK_PALSU)`: 2
  - `MENELAN_ERROR (KOSONG)`: 14
  - `MENELAN_ERROR (LOG_ONLY)`: 20
  - `MENELAN_ERROR (SILENT_DEFAULT)`: 5
  - `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)`: 7
  - `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)`: 31
  - `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)`: 14
  - `SAH (PARSING_DEFENSIF)`: 1

> [!CRITICAL]
> Dari 94 blok `catch` di `lib/`, sebanyak **49 blok menelan error secara diam-diam** (silent swallow / fake fallback / developer.log only). Ini merupakan pelanggaran langsung terhadap **Golden Rule R1** (*Tidak ada catch yang menelan error*).

---

## 2. KATALOG LENGKAP BLOK CATCH DI `lib/`

| # | File & Baris | Parameter | Klasifikasi | Analisis & Dampak |
| :- | :--- | :--- | :--- | :--- |
| 1 | [main.dart:25](file:////home/ganendra/qrypta/lib/main.dart#L25) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 2 | [main.dart:33](file:////home/ganendra/qrypta/lib/main.dart#L33) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 3 | [main.dart:102](file:////home/ganendra/qrypta/lib/main.dart#L102) | `e, stack` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 4 | [mrz_parser.dart:259](file:////home/ganendra/qrypta/lib/src/core/utils/mrz_parser.dart#L259) | `_` | `SAH (PARSING_DEFENSIF)` | Parsing defensif untuk validasi format (misal parse tanggal / format address) mengembalikan false/null. |
| 5 | [btid_credential_model.dart:41](file:////home/ganendra/qrypta/lib/src/core/data/models/btid_credential_model.dart#L41) | `_` | `MENELAN_ERROR (SILENT_DEFAULT)` | Mengembalikan default diam-diam saat operasi runtime gagal tanpa AppFailure. |
| 6 | [authentication_service.dart:18](file:////home/ganendra/qrypta/lib/src/core/services/authentication_service.dart#L18) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 7 | [erc20_service.dart:130](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/erc20_service.dart#L130) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 8 | [erc20_service.dart:190](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/erc20_service.dart#L190) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 9 | [erc20_service.dart:245](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/erc20_service.dart#L245) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 10 | [erc20_service.dart:286](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/erc20_service.dart#L286) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 11 | [native_currency_service.dart:21](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/native_currency_service.dart#L21) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 12 | [native_currency_service.dart:49](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/native_currency_service.dart#L49) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 13 | [transaction_service.dart:95](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L95) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 14 | [transaction_service.dart:161](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L161) | `e, s` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 15 | [transaction_service.dart:208](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L208) | `e, s` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 16 | [transaction_service.dart:225](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L225) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 17 | [transaction_service.dart:253](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L253) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 18 | [verification_transaction_service.dart:143](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L143) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 19 | [verification_transaction_service.dart:226](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L226) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 20 | [verification_transaction_service.dart:287](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L287) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 21 | [verification_transaction_service.dart:352](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L352) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 22 | [verification_transaction_service.dart:410](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L410) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 23 | [verification_transaction_service.dart:441](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L441) | `_` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 24 | [verification_transaction_service.dart:471](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/verification_transaction_service.dart#L471) | `_` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 25 | [wallet_service.dart:16](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/wallet_service.dart#L16) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 26 | [tab_pay.dart:50](file:////home/ganendra/qrypta/lib/src/features/home/presentation/tabs/tab_pay.dart#L50) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 27 | [qr_scanner_screen.dart:76](file:////home/ganendra/qrypta/lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart#L76) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 28 | [security_settings_provider.dart:47](file:////home/ganendra/qrypta/lib/src/features/profile/presentation/providers/security_settings_provider.dart#L47) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 29 | [security_settings_provider.dart:62](file:////home/ganendra/qrypta/lib/src/features/profile/presentation/providers/security_settings_provider.dart#L62) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 30 | [test_connection_page.dart:31](file:////home/ganendra/qrypta/lib/src/features/testing/test_connection_page.dart#L31) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 31 | [consent_request_screen.dart:172](file:////home/ganendra/qrypta/lib/src/features/verification/presentation/screens/consent_request_screen.dart#L172) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 32 | [consent_request_screen.dart:204](file:////home/ganendra/qrypta/lib/src/features/verification/presentation/screens/consent_request_screen.dart#L204) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 33 | [privacy_audit_screen.dart:185](file:////home/ganendra/qrypta/lib/src/features/verification/presentation/screens/privacy_audit_screen.dart#L185) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 34 | [verification_controller.dart:122](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L122) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 35 | [verification_controller.dart:201](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L201) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 36 | [verification_controller.dart:231](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L231) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 37 | [verification_controller.dart:270](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L270) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 38 | [verification_controller.dart:281](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L281) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 39 | [confirmation_screen.dart:55](file:////home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/confirmation_screen.dart#L55) | `e, s` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 40 | [levy_payment_screen.dart:602](file:////home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/levy_payment_screen.dart#L602) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 41 | [qris_payment_screen.dart:448](file:////home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/qris_payment_screen.dart#L448) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 42 | [send_scanner_screen.dart:40](file:////home/ganendra/qrypta/lib/src/features/transaction/presentation/screens/send_scanner_screen.dart#L40) | `e, s` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 43 | [payment_controller.dart:207](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L207) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 44 | [payment_controller.dart:208](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L208) | `e` | `MENELAN_ERROR (FALLBACK_PALSU)` | KRITIS: Membuat hash transaksi palsu lokal saat RPC gagal lalu menyatakan sukses (R1, R2, F-03, F-04). |
| 45 | [payment_controller.dart:241](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L241) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 46 | [payment_controller.dart:244](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L244) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 47 | [payment_controller.dart:343](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L343) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 48 | [payment_controller.dart:344](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L344) | `e` | `MENELAN_ERROR (FALLBACK_PALSU)` | KRITIS: Membuat hash transaksi palsu lokal saat RPC gagal lalu menyatakan sukses (R1, R2, F-03, F-04). |
| 49 | [payment_controller.dart:367](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L367) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 50 | [payment_controller.dart:370](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L370) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 51 | [send_controller.dart:102](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/send_controller.dart#L102) | `e, s` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 52 | [transaction_controller.dart:36](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/transaction_controller.dart#L36) | `e, s` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 53 | [transaction_controller.dart:59](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/transaction_controller.dart#L59) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 54 | [transaction_controller.dart:76](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/transaction_controller.dart#L76) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 55 | [btid_provider.dart:40](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L40) | `_` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 56 | [btid_provider.dart:49](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L49) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 57 | [btid_provider.dart:63](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L63) | `_` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 58 | [btid_provider.dart:67](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L67) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 59 | [btid_provider.dart:86](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L86) | `_` | `MENELAN_ERROR (KOSONG)` | Blok catch kosong total tanpa penanganan maupun logging. Pelanggaran keras R1 & F-21. |
| 60 | [pin_provider.dart:38](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/pin_provider.dart#L38) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 61 | [pin_provider.dart:49](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/pin_provider.dart#L49) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 62 | [wallet_provider.dart:51](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/wallet_provider.dart#L51) | `e` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 63 | [btid_issued_screen.dart:95](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/btid_issued_screen.dart#L95) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 64 | [btid_issued_screen.dart:108](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/btid_issued_screen.dart#L108) | `e` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 65 | [mrz_scanner_screen.dart:46](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/mrz_scanner_screen.dart#L46) | `_` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 66 | [wallet_setup_screen.dart:80](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/wallet_setup_screen.dart#L80) | `e, stackTrace` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 67 | [wallet_setup_screen.dart:121](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/screens/wallet_setup_screen.dart#L121) | `e, stackTrace` | `MENELAN_ERROR (LOG_ONLY)` | TINGGI: Hanya mencatat log via developer.log/debugPrint, operasi gagal ditelan tanpa melempar AppFailure (R1). |
| 68 | [generate_mnemonic_usecase.dart:17](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/generate_mnemonic_usecase.dart#L17) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 69 | [get_checksum_address_usecase.dart:15](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/get_checksum_address_usecase.dart#L15) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 70 | [get_pin_usecase.dart:16](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/get_pin_usecase.dart#L16) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 71 | [get_private_key_from_mnemonic_usecase.dart:16](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/get_private_key_from_mnemonic_usecase.dart#L16) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 72 | [get_private_key_usecase.dart:17](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/get_private_key_usecase.dart#L17) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 73 | [get_public_key_usecase.dart:16](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/get_public_key_usecase.dart#L16) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 74 | [save_mnemonic_usecase.dart:15](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/save_mnemonic_usecase.dart#L15) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 75 | [save_pin_usecase.dart:15](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/save_pin_usecase.dart#L15) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 76 | [save_private_key_usecase.dart:16](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/save_private_key_usecase.dart#L16) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 77 | [verify_pin_usecase.dart:16](file:////home/ganendra/qrypta/lib/src/features/authentication/domain/usecases/verify_pin_usecase.dart#L16) | `e, s` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 78 | [authentication_repository_impl.dart:32](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L32) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 79 | [authentication_repository_impl.dart:47](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L47) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 80 | [authentication_repository_impl.dart:57](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L57) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 81 | [authentication_repository_impl.dart:70](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L70) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 82 | [authentication_repository_impl.dart:85](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L85) | `e` | `MENELAN_ERROR (SILENT_DEFAULT)` | Mengembalikan default diam-diam saat operasi runtime gagal tanpa AppFailure. |
| 83 | [authentication_repository_impl.dart:103](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L103) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 84 | [authentication_repository_impl.dart:114](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L114) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 85 | [authentication_repository_impl.dart:129](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L129) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 86 | [authentication_repository_impl.dart:143](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L143) | `e` | `MENELAN_ERROR (SILENT_DEFAULT)` | Mengembalikan default diam-diam saat operasi runtime gagal tanpa AppFailure. |
| 87 | [authentication_repository_impl.dart:153](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L153) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 88 | [authentication_repository_impl.dart:162](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L162) | `e` | `MENELAN_ERROR (SILENT_DEFAULT)` | Mengembalikan default diam-diam saat operasi runtime gagal tanpa AppFailure. |
| 89 | [authentication_repository_impl.dart:180](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L180) | `e` | `MENGUBAH_KE_FAILURE (RETHROW/EXCEPTION)` | Melempar ulang Exception / error ke pemanggil. |
| 90 | [authentication_repository_impl.dart:203](file:////home/ganendra/qrypta/lib/src/features/authentication/data/repositories/authentication_repository_impl.dart#L203) | `e` | `MENELAN_ERROR (SILENT_DEFAULT)` | Mengembalikan default diam-diam saat operasi runtime gagal tanpa AppFailure. |
| 91 | [token_provider.dart:53](file:////home/ganendra/qrypta/lib/src/features/tokens/presentation/providers/token_provider.dart#L53) | `e` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 92 | [token_provider.dart:61](file:////home/ganendra/qrypta/lib/src/features/tokens/presentation/providers/token_provider.dart#L61) | `e, s` | `MENGUBAH_KE_FAILURE (UI_ERROR_STATE)` | Meneruskan status error ke state reaktif UI atau menampilkan snackbar error. |
| 93 | [blockchain_service_testing.dart:29](file:////home/ganendra/qrypta/lib/testing blockchain/blockchain_service_testing.dart#L29) | `e` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |
| 94 | [chain_service_testing.dart:20](file:////home/ganendra/qrypta/lib/testing blockchain/chain_service_testing.dart#L20) | `e` | `MENELAN_ERROR (TIDAK_TERKLASIFIKASI)` | Catch tidak melempar AppFailure terstruktur. |

---

## 3. VERIFIKASI BLOK KOSONG TOTAL `catch (_) {}` (F-21)

Berikut adalah 14 lokasi blok `catch (_) {}` kosong tanpa instruksi apapun di dalamnya:

| # | Lokasi File | Baris | Konteks Kode | Rencana Remedi |
| :- | :--- | :--- | :--- | :--- |
| 1 | [transaction_service.dart:253](file:////home/ganendra/qrypta/lib/src/core/services/blockchain/transaction_service.dart#L253) | 253 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 2 | [tab_pay.dart:50](file:////home/ganendra/qrypta/lib/src/features/home/presentation/tabs/tab_pay.dart#L50) | 50 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 3 | [qr_scanner_screen.dart:76](file:////home/ganendra/qrypta/lib/src/features/qr_scanner/presentation/screens/qr_scanner_screen.dart#L76) | 76 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 4 | [verification_controller.dart:122](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L122) | 122 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 5 | [verification_controller.dart:281](file:////home/ganendra/qrypta/lib/src/features/verification/logic/verification_controller.dart#L281) | 281 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 6 | [payment_controller.dart:207](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L207) | 207 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 7 | [payment_controller.dart:241](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L241) | 241 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 8 | [payment_controller.dart:244](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L244) | 244 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 9 | [payment_controller.dart:343](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L343) | 343 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 10 | [payment_controller.dart:367](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L367) | 367 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 11 | [payment_controller.dart:370](file:////home/ganendra/qrypta/lib/src/features/transaction/logic/payment_controller.dart#L370) | 370 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 12 | [btid_provider.dart:49](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L49) | 49 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 13 | [btid_provider.dart:67](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L67) | 67 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |
| 14 | [btid_provider.dart:86](file:////home/ganendra/qrypta/lib/src/features/authentication/presentation/providers/btid_provider.dart#L86) | 86 | Swallows silently | Ganti dengan typed `AppFailure` atau daftarkan ke OutboxWorker. |

---

## 4. VERIFIKASI PEMALSUAN TRANSAKSI (F-03, F-03b, F-04)

| ID | File | Baris | Logika Pemalsuan | Status Audit |
| :- | :--- | :--- | :--- | :--- |
| F-03 | `lib/src/features/transaction/logic/payment_controller.dart` | 208-213 | `fallbackSeed = "$levyRef-$userWallet-..."` -> `keccak256` | **TERVERIFIKASI AKTIF** |
| F-03b | `lib/src/features/transaction/logic/payment_controller.dart` | 214-220 | `fallbackSeed = "$levyRef-card-..."` -> `keccak256` (Jalur Visa/Counter) | **TERVERIFIKASI AKTIF (GAP AUDIT DITUTUP)** |
| F-04 | `lib/src/features/transaction/logic/payment_controller.dart` | 344-349 | `fallbackSeed = "$payRef-$userWallet-..."` -> `keccak256` | **TERVERIFIKASI AKTIF** |

