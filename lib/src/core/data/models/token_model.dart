class TokenModel {
  final String contractAddress; // Address of the token contract
  final String symbol;
  final String name;
  final int decimals;
  final BigInt balance; // Use BigInt for precision
  final String? logoUrl;

  TokenModel({
    required this.contractAddress,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.balance,
    this.logoUrl,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      contractAddress: json['address'] as String, // Assuming 'address' is the field from GraphQL
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      balance: BigInt.parse(json['balance'] as String), // Parse balance as BigInt
      logoUrl: json['logoUrl'] as String?,
    );
  }
}