import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

// Placeholder GraphQL endpoint. Please update this with your actual GraphQL server URL.
const String _kGraphQLEndpoint = 'http://localhost:4000/graphql';

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  final HttpLink httpLink = HttpLink(_kGraphQLEndpoint);

  // Initialize Hive for caching
  // Ensure Hive is initialized before this provider is accessed.
  // e.g., await Hive.initFlutter(); in main()
  final GraphQLCache cache = GraphQLCache(store: HiveStore());

  return GraphQLClient(
    link: httpLink,
    cache: cache,
  );
});