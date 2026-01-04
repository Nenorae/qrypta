class TokenModel {
  final String symbol;
  final String name;
  final int decimals;
  final BigInt balance; // Use BigInt for precision
  final String? logoUrl;

  TokenModel({
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.balance,
    this.logoUrl,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      balance: BigInt.parse(json['balance'] as String), // Parse balance as BigInt
      logoUrl: json['logoUrl'] as String?,
    );
  }
}