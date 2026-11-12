import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final endpoint = dotenv.isInitialized
      ? (dotenv.env['GRAPHQL_URL'] ?? 'http://127.0.0.1:4000/graphql')
      : 'http://127.0.0.1:4000/graphql';
  final HttpLink httpLink = HttpLink(endpoint);

  // Initialize Hive for caching
  final GraphQLCache cache = GraphQLCache(store: HiveStore());

  return GraphQLClient(
    link: httpLink,
    cache: cache,
  );
});
