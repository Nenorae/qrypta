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

  Token copyWith({
    String? contractAddress,
    String? name,
    String? symbol,
    int? decimals,
    BigInt? balance,
  }) {
    return Token(
      contractAddress: contractAddress ?? this.contractAddress,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      decimals: decimals ?? this.decimals,
      balance: balance ?? this.balance,
    );
  }
}
