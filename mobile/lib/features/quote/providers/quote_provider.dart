import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../data/quote_repository.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(apiClientProvider)),
);
