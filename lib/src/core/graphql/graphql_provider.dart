// lib/src/core/graphql/graphql_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:qrypta/src/core/config/app_config.dart';

/// Provides the canonical GraphQLClient configured with [AppConfig.graphqlUrl].
/// Eliminated loopback fallbacks and dotenv (F-02, F-20).
final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final endpoint = AppConfig.graphqlUrl;
  final HttpLink httpLink = HttpLink(endpoint);

  // Initialize Hive for caching
  final GraphQLCache cache = GraphQLCache(store: HiveStore());

  return GraphQLClient(
    link: httpLink,
    cache: cache,
  );
});
