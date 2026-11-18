// lib/src/core/transaction/state_machine/tx_state.dart

/// Siklus hidup status transaksi on-chain sesuai Phase 2.2.
enum TxState {
  idle,
  preparing,
  signing,
  broadcasting,
  pending,
  confirmed,
  failed,
  reverted,
  timeout;

  /// Transaksi telah mencapai status akhir permanen.
  bool get isTerminal => this == confirmed || this == failed || this == reverted;

  /// Transaksi sedang dalam proses eksekusi aktif.
  bool get isInFlight =>
      this == preparing || this == signing || this == broadcasting || this == pending;

  /// Transaksi gagal atau timeout dan dapat dipulihkan/dicoba ulang.
  bool get canRetry => this == failed || this == timeout || this == reverted;

  /// Memvalidasi aturan transisi state machine.
  /// Mencegah lompatan ilegal (mis. idle -> confirmed tanpa proses broadcast).
  bool canTransitionTo(TxState next) {
    if (this == next) return true; // Idempotent same-state
    switch (this) {
      case TxState.idle:
        return next == TxState.preparing;
      case TxState.preparing:
        return next == TxState.signing || next == TxState.failed;
      case TxState.signing:
        return next == TxState.broadcasting || next == TxState.failed;
      case TxState.broadcasting:
        return next == TxState.pending || next == TxState.failed;
      case TxState.pending:
        return next == TxState.confirmed ||
            next == TxState.failed ||
            next == TxState.reverted ||
            next == TxState.timeout;
      case TxState.timeout:
        return next == TxState.confirmed ||
            next == TxState.reverted ||
            next == TxState.failed ||
            next == TxState.pending;
      case TxState.failed:
      case TxState.reverted:
      case TxState.confirmed:
        return false;
    }
  }
}
