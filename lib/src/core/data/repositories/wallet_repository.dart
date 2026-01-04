import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:qrypta/src/core/graphql/queries.dart';
import 'package:qrypta/src/core/graphql/graphql_provider.dart'; // Import the new GraphQL provider

class WalletRepository {
  final GraphQLClient client;

  WalletRepository(this.client);

  Stream<QueryResult> watchWalletAssets(String address) {
    final WatchQueryOptions options = WatchQueryOptions(
      document: gql(getMyWalletQuery),
      variables: <String, dynamic>{
        'address': address,
      },
      fetchResults: true,
      // Using cacheAndNetwork as per the plan's DO's and DON'Ts
      fetchPolicy: FetchPolicy.cacheAndNetwork, 
    );

    return client.watchQuery(options).stream;
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final GraphQLClient graphqlClient = ref.read(graphqlClientProvider);
  return WalletRepository(graphqlClient);
});
