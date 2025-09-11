class Token {
  final String contractAddress;
  final String name;
  final String symbol;
  final int decimals;
  BigInt? balance; // Saldo bisa null sampai berhasil di-fetch

  Token({
    required this.contractAddress,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.balance,
  });
}
