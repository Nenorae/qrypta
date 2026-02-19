const String getMyAssetsQuery = r'''
query MyAssets($walletAddress: String!) {
  myAssets(walletAddress: $walletAddress) {
    token {
      address
      name
      symbol
      decimals
      logoUrl
      tokenType
    }
    balance
  }
}
''';

const String getDiscoverTokensQuery = r'''
query DiscoverTokens($limit: Int!, $offset: Int!) {
  discoverTokens(limit: $limit, offset: $offset) {
    address
    name
    symbol
    decimals
    logoUrl
    tokenType
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