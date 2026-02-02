const String getMyWalletQuery = r'''
query GetMyWallet($address: String!) {
  tokenAsset(address: $address) {
    tokens {
      symbol
      name
      decimals
      balance
      logoUrl
    }
  }
}
''';

const String sendRawTransactionMutation = r'''
mutation SendRawTransaction($signedTransactionHex: String!) {
  sendTransaction(signedTransactionHex: $signedTransactionHex) {
    txHash
  }
}
''';