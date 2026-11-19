// lib/src/core/providers/merchant_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrypta/src/core/services/merchant/merchant_resolver_service.dart';

/// Provider instance singleton [MerchantResolverService] untuk injeksi dependency dan pengujian.
final merchantResolverServiceProvider = Provider<MerchantResolverService>((ref) {
  return MerchantResolverService();
});
