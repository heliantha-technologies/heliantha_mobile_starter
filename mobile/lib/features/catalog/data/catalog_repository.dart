import '../../../core/api/api_client.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;
  final Map<String, _CacheEntry<List<Product>>> _productsCache = {};
  final Map<String, _CacheEntry<Product>> _productCache = {};
  final Set<String> _loadedProductDetails = {};
  _CacheEntry<List<Category>>? _categoriesCache;

  static const _cacheTtl = Duration(seconds: 45);
  static const _detailCacheTtl = Duration(minutes: 2);
  static const _categoriesCacheTtl = Duration(minutes: 5);

  Future<List<Category>> categories({
    int? languageId,
  }) async {
    final cached = _categoriesCache;
    if (cached != null && cached.isFresh) {
      return cached.value;
    }

    final response = await _api.dio.get(
      '/v1/categories',
      queryParameters: {
        if (languageId != null) 'language_id': languageId,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    final rows =
        data.whereType<Map<String, dynamic>>().map(Category.fromJson).toList();
    _categoriesCache = _CacheEntry(
      rows,
      DateTime.now().add(_categoriesCacheTtl),
    );
    return rows;
  }

  Future<List<Product>> products({
    int page = 1,
    int pageSize = 20,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) async {
    final key = _productsKey(
      page: page,
      pageSize: pageSize,
      category: category,
      query: query,
      languageId: languageId,
      currencyId: currencyId,
    );
    final cached = _productsCache[key];
    if (cached != null && cached.isFresh) {
      return cached.value;
    }

    final response = await _api.dio.get(
      '/v1/products',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (category != null) 'category': category,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (languageId != null) 'language_id': languageId,
        if (currencyId != null) 'currency_id': currencyId,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    final rows =
        data.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
    _productsCache[key] = _CacheEntry(
      rows,
      DateTime.now().add(_cacheTtl),
    );
    for (final product in rows) {
      final productKey = _productKey(product.id, languageId, currencyId);
      if (!_loadedProductDetails.contains(productKey)) {
        _productCache[productKey] = _CacheEntry(
          product,
          DateTime.now().add(_detailCacheTtl),
        );
      }
    }
    return rows;
  }

  void prefetchProducts({
    int page = 1,
    int pageSize = 20,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) {
    final key = _productsKey(
      page: page,
      pageSize: pageSize,
      category: category,
      query: query,
      languageId: languageId,
      currencyId: currencyId,
    );
    final cached = _productsCache[key];
    if (cached != null && cached.isFresh) {
      return;
    }
    products(
      page: page,
      pageSize: pageSize,
      category: category,
      query: query,
      languageId: languageId,
      currencyId: currencyId,
    );
  }

  Future<Product> product(
    int id, {
    int? languageId,
    int? currencyId,
    bool forceRefresh = false,
  }) async {
    final key = _productKey(id, languageId, currencyId);
    final cached = _productCache[key];
    if (!forceRefresh &&
        cached != null &&
        cached.isFresh &&
        _loadedProductDetails.contains(key)) {
      return cached.value;
    }

    final response = await _api.dio.get(
      '/v1/products/$id',
      queryParameters: {
        if (languageId != null) 'language_id': languageId,
        if (currencyId != null) 'currency_id': currencyId,
      },
    );
    final product = Product.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
    _productCache[key] = _CacheEntry(
      product,
      DateTime.now().add(_detailCacheTtl),
    );
    _loadedProductDetails.add(key);
    return product;
  }

  void rememberProduct(Product product, {int? languageId, int? currencyId}) {
    final key = _productKey(product.id, languageId, currencyId ?? product.currencyId);
    if (_loadedProductDetails.contains(key)) {
      return;
    }
    _productCache[key] = _CacheEntry(
      product,
      DateTime.now().add(_detailCacheTtl),
    );
  }

  String _productKey(int id, int? languageId, int? currencyId) =>
      '$id|${languageId ?? ''}|${currencyId ?? ''}';

  String _productsKey({
    required int page,
    required int pageSize,
    required int? category,
    required String? query,
    required int? languageId,
    required int? currencyId,
  }) {
    return [
      page,
      pageSize,
      category ?? '',
      query?.trim() ?? '',
      languageId ?? '',
      currencyId ?? '',
    ].join('|');
  }
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}
