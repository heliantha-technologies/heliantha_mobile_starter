import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/store_context.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/product_grid.dart';
import '../providers/catalog_providers.dart';
import '../providers/store_context_provider.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialCategory,
    this.initialQuery,
    this.openCategories = false,
  });

  final int? initialCategory;
  final String? initialQuery;
  final bool openCategories;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  static const _pageSize = 30;
  static const _loadMoreThreshold = 520.0;

  late final TextEditingController _search;
  late final ScrollController _scrollController;
  List<Product>? _products;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _currentSearchRequestId = 0;
  Timer? _searchDebounce;
  bool _openedCategoriesFromRoute = false;
  bool _showSmartScrollButton = false;

  bool get _hasSearch => _search.text.trim().isNotEmpty;
  int? get _categoryFilter => widget.initialCategory;
  String? get _queryFilter {
    final query = _search.text.trim();
    return query.isEmpty ? null : query;
  }

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery ?? '');
    _scrollController = ScrollController();
    _search.addListener(_onSearchChanged);
    _scrollController.addListener(_onCatalogScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFirstPage();
        _openCategoriesFromRouteIfNeeded();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialQuery != widget.initialQuery;

    if (routeChanged) {
      _searchDebounce?.cancel();
      _search.text = widget.initialQuery ?? '';
      _loadFirstPage();
    }
    if (!oldWidget.openCategories && widget.openCategories) {
      _openedCategoriesFromRoute = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCategoriesFromRouteIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onCatalogScroll);
    _scrollController.dispose();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _loadFirstPage,
    );
  }

  void _onCatalogScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final shouldShow = _scrollController.offset > 160;
    if (shouldShow != _showSmartScrollButton && mounted) {
      setState(() => _showSmartScrollButton = shouldShow);
    }
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _smartScrollBack() async {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final current = position.pixels;
    final max = position.maxScrollExtent;
    final middle = max * 0.48;
    final target = current > middle + 120 ? middle : 0.0;
    final distance = (current - target).abs();
    final duration = Duration(
      milliseconds: (260 + distance / 5).clamp(320, 760).round(),
    );
    final clampedTarget = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    await _scrollController.animateTo(
      clampedTarget,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  void _loadMoreIfContentIsShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_hasMore ||
          _loading ||
          _loadingMore ||
          !_scrollController.hasClients) {
        return;
      }

      if (_scrollController.position.extentAfter < _loadMoreThreshold) {
        _loadMore();
      }
    });
  }

  Future<({int? languageId, int? currencyId})> _storeSelection() async {
    try {
      final context = await ref.read(storeContextProvider.future);
      return (
        languageId: context.effectiveLanguageId(
          ref.read(selectedLanguageIdProvider),
        ),
        currencyId: context.effectiveCurrencyId(
          ref.read(selectedCurrencyIdProvider),
        ),
      );
    } catch (_) {
      return (
        languageId: ref.read(selectedLanguageIdProvider),
        currencyId: ref.read(selectedCurrencyIdProvider),
      );
    }
  }

  Future<void> _loadFirstPage() async {
    _searchDebounce?.cancel();
    final requestId = ++_currentSearchRequestId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _products = null;
      _page = 1;
      _hasMore = false;
    });

    try {
      final repo = ref.read(catalogRepositoryProvider);
      final selection = await _storeSelection();
      final rows = await repo.products(
        page: 1,
        pageSize: _pageSize,
        category: _categoryFilter,
        query: _queryFilter,
        languageId: selection.languageId,
        currencyId: selection.currencyId,
      );
      if (mounted) {
        if (requestId != _currentSearchRequestId) {
          return;
        }
        setState(() {
          _products = rows;
          _page = 1;
          _hasMore = rows.length == _pageSize;
        });
        _loadMoreIfContentIsShort();
        if (_hasMore) {
          repo.prefetchProducts(
            page: 2,
            pageSize: _pageSize,
            category: _categoryFilter,
            query: _queryFilter,
            languageId: selection.languageId,
            currencyId: selection.currencyId,
          );
        }
      }
    } catch (error) {
      if (mounted && requestId == _currentSearchRequestId) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && requestId == _currentSearchRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) {
      return;
    }

    final requestId = ++_currentSearchRequestId;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final selection = await _storeSelection();
      final nextPage = _page + 1;
      final rows = await repo.products(
        page: nextPage,
        pageSize: _pageSize,
        category: _categoryFilter,
        query: _queryFilter,
        languageId: selection.languageId,
        currencyId: selection.currencyId,
      );
      if (mounted && requestId == _currentSearchRequestId) {
        setState(() {
          _products = [...?_products, ...rows];
          _page = nextPage;
          _hasMore = rows.length == _pageSize;
        });
        _loadMoreIfContentIsShort();
      }
    } catch (e) {
      if (!mounted || requestId != _currentSearchRequestId) {
        return;
      }
      AppFeedback.error(
        context,
        'Nous n’avons pas pu charger plus de produits pour le moment.',
      );
    } finally {
      if (mounted && requestId == _currentSearchRequestId) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _clearSearch() {
    _search.clear();
    _loadFirstPage();
  }

  void _openCategoriesFromRouteIfNeeded() {
    if (!mounted || !widget.openCategories || _openedCategoriesFromRoute) {
      return;
    }
    _openedCategoriesFromRoute = true;
    _openCategoryPicker();
  }

  Future<void> _openCategoryPicker() async {
    final categories = await ref.read(categoriesProvider.future);
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (_) => _CategoryPickerSheet(
        categories: categories,
        selectedCategoryId: _categoryFilter,
      ),
    );
    if (!mounted) {
      return;
    }
    if (selected == -1) {
      _goToCategory(null);
    } else if (selected != null) {
      _goToCategory(selected);
    }
  }

  void _goToCategory(int? categoryId) {
    final query = _queryFilter;
    final params = <String, String>{};
    if (categoryId != null) {
      params['category'] = '$categoryId';
    }
    if (query != null) {
      params['q'] = query;
    }
    final uri = Uri(
      path: '/catalog',
      queryParameters: params.isEmpty ? null : params,
    );
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final products = _products ?? const <Product>[];
    final storeContext = ref.watch(storeContextProvider).valueOrNull;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final activeCategory = _activeCategory(categories);

    return Scaffold(
      appBar: AppTopBar(
        subtitle: 'Catalogue solaire',
        actions: _contextActions(storeContext) ?? const [],
      ),
      floatingActionButton: _SmartScrollBackButton(
        visible: _showSmartScrollButton,
        onPressed: _smartScrollBack,
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          // Le rebond reste confortable sur iOS/Android. Sur le Web, le
          // défilement natif évite l'inertie excessive à la souris/au trackpad.
          physics: kIsWeb
              ? const ClampingScrollPhysics()
              : const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              floating: true,
              delegate: _CatalogHeaderDelegate(
                controller: _search,
                hasSearch: _hasSearch,
                onClear: _clearSearch,
                onSearch: _loadFirstPage,
                isDesktop: MediaQuery.sizeOf(context).width >= 768,
                activeCategory: activeCategory,
                productCount: products.length,
                showProductCount: !_loading && _error == null,
                onOpenCategories: _openCategoryPicker,
              ),
            ),
            _CatalogContentSliver(
              loading: _loading,
              error: _error,
              products: products,
              loadingMore: _loadingMore,
              onRetry: _loadFirstPage,
              onOpenProduct: (product) {
                ref.read(catalogRepositoryProvider).rememberProduct(product);
                context.push(
                  '/product/${product.id}',
                  extra: product,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Category? _activeCategory(List<Category> categories) {
    final id = _categoryFilter;
    if (id == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  List<Widget>? _contextActions(StoreContext? context) {
    if (context == null) {
      return null;
    }

    final actions = <Widget>[];
    final currentLanguageId = ref.watch(selectedLanguageIdProvider);
    final currentCurrencyId = ref.watch(selectedCurrencyIdProvider);

    if (context.languages.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Langue',
          offset: const Offset(0, 42),
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Colors.white,
          onSelected: (id) async {
            await ref.read(selectedLanguageIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final language in context.languages)
              PopupMenuItem<int>(
                value: language.id,
                child: Row(
                  children: [
                    Text(
                      language.name,
                      style: TextStyle(
                        fontWeight: language.id == currentLanguageId
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: language.id == currentLanguageId
                            ? AppColors.navy
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (language.id == currentLanguageId) ...[
                      const Spacer(),
                      const Icon(Icons.check_rounded,
                          size: 18, color: Color(0xFF7C3AED)),
                    ],
                  ],
                ),
              ),
          ],
          child: const TopBarActionPastille(
            icon: Icons.language_rounded,
            iconColor: Color(0xFF7C3AED),
            backgroundColor: Color(0xFFEDE9FE),
            gradientColors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
            borderColor: Color(0xFF7C3AED),
            shadowColor: Color(0xFF7C3AED),
          ),
        ),
      );
    }

    if (context.currencies.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Devise',
          offset: const Offset(0, 42),
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: Colors.white,
          onSelected: (id) async {
            await ref.read(selectedCurrencyIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final currency in context.currencies)
              PopupMenuItem<int>(
                value: currency.id,
                child: Row(
                  children: [
                    Text(
                      currency.isoCode,
                      style: TextStyle(
                        fontWeight: currency.id == currentCurrencyId
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: currency.id == currentCurrencyId
                            ? AppColors.navy
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (currency.id == currentCurrencyId) ...[
                      const Spacer(),
                      const Icon(Icons.check_rounded,
                          size: 18, color: Color(0xFFD97706)),
                    ],
                  ],
                ),
              ),
          ],
          child: const TopBarActionPastille(
            icon: Icons.payments_rounded,
            iconColor: Color(0xFFD97706),
            backgroundColor: Color(0xFFFEF3C7),
            gradientColors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            borderColor: Color(0xFFF59E0B),
            shadowColor: Color(0xFFD97706),
          ),
        ),
      );
    }

    return actions.isEmpty ? null : actions;
  }
}

String _productCountLabel(int count) {
  return count == 1 ? '1 produit' : '$count produits';
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<Category> categories;
  final int? selectedCategoryId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = widget.categories.length > 8;
    final query = _search.text.trim().toLowerCase();
    final categories = query.isEmpty
        ? widget.categories
        : widget.categories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                child: Row(
                  children: [
                    const AppIconBadge(icon: Icons.grid_view_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Catégories',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (canSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une catégorie...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  children: [
                    _CategoryChoiceTile(
                      icon: Icons.all_inclusive_rounded,
                      title: 'Tous les produits',
                      selected: widget.selectedCategoryId == null,
                      onTap: () => Navigator.of(context).pop(-1),
                    ),
                    const SizedBox(height: 8),
                    for (final category in categories)
                      _CategoryChoiceTile(
                        icon: _categoryIcon(category.name),
                        title: category.name,
                        selected: widget.selectedCategoryId == category.id,
                        onTap: () => Navigator.of(context).pop(category.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('panneau')) return Icons.solar_power_rounded;
    if (value.contains('onduleur')) return Icons.electric_bolt_rounded;
    if (value.contains('batter')) return Icons.battery_charging_full_rounded;
    if (value.contains('pompe')) return Icons.water_drop_rounded;
    if (value.contains('groupe')) return Icons.power_rounded;
    if (value.contains('éclairage') || value.contains('eclairage')) {
      return Icons.lightbulb_outline_rounded;
    }
    return Icons.category_rounded;
  }
}

class _CategoryChoiceTile extends StatelessWidget {
  const _CategoryChoiceTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      backgroundColor: selected ? AppColors.softSun : AppColors.surface,
      borderColor: selected ? AppColors.sun : AppColors.border,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: selected ? AppColors.navy : AppColors.blue,
            backgroundColor: selected ? AppColors.sun : AppColors.softBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppColors.navy),
        ],
      ),
    );
  }
}

class _CatalogSearchBar extends StatelessWidget {
  const _CatalogSearchBar({
    required this.controller,
    required this.hasSearch,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool hasSearch;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SearchBar(
        controller: controller,
        constraints: const BoxConstraints(
          minHeight: 44,
          maxHeight: 44,
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.premiumLine),
          ),
        ),
        hintText: 'Rechercher un panneau, onduleur...',
        leading: const Icon(Icons.search_rounded, color: AppColors.muted),
        trailing: [
          if (hasSearch)
            IconButton(
              tooltip: 'Effacer',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
            ),
          IconButton(
            tooltip: 'Rechercher',
            onPressed: onSearch,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.blue,
            ),
          ),
        ],
        onSubmitted: (_) => onSearch(),
      ),
    );
  }
}

class _CatalogHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CatalogHeaderDelegate({
    required this.controller,
    required this.hasSearch,
    required this.onClear,
    required this.onSearch,
    required this.isDesktop,
    required this.activeCategory,
    required this.productCount,
    required this.showProductCount,
    required this.onOpenCategories,
  });

  final TextEditingController controller;
  final bool hasSearch;
  final VoidCallback onClear;
  final VoidCallback onSearch;
  final bool isDesktop;
  final Category? activeCategory;
  final int productCount;
  final bool showProductCount;
  final VoidCallback onOpenCategories;

  @override
  double get minExtent => isDesktop ? 68 : 64;

  @override
  double get maxExtent => isDesktop ? 116 : 112;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final expansion =
        (1 - shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0).toDouble();
    final topPadding = isDesktop ? 12.0 : 10.0;
    final bottomPadding = (isDesktop ? 12.0 : 10.0) + (2.0 * expansion);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                topPadding,
                16,
                bottomPadding,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: _CatalogSearchBar(
                      controller: controller,
                      hasSearch: hasSearch,
                      onClear: onClear,
                      onSearch: onSearch,
                    ),
                  ),
                  SizedBox(height: 6 * expansion),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: expansion,
                      child: Opacity(
                        opacity: expansion,
                        child: SizedBox(
                          height: 40,
                          child: _CatalogSecondaryRow(
                            activeCategory: activeCategory,
                            productCount: productCount,
                            showProductCount: showProductCount,
                            onOpenCategories: onOpenCategories,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CatalogHeaderDelegate oldDelegate) {
    return controller != oldDelegate.controller ||
        hasSearch != oldDelegate.hasSearch ||
        isDesktop != oldDelegate.isDesktop ||
        activeCategory?.id != oldDelegate.activeCategory?.id ||
        productCount != oldDelegate.productCount ||
        showProductCount != oldDelegate.showProductCount;
  }
}

class _CatalogSecondaryRow extends StatelessWidget {
  const _CatalogSecondaryRow({
    required this.activeCategory,
    required this.productCount,
    required this.showProductCount,
    required this.onOpenCategories,
  });

  final Category? activeCategory;
  final int productCount;
  final bool showProductCount;
  final VoidCallback onOpenCategories;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: FilledButton.tonalIcon(
            onPressed: onOpenCategories,
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: Text(
              activeCategory?.name ?? 'Catégories',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        if (showProductCount) ...[
          const SizedBox(width: 8),
          InfoPill(
            icon: Icons.inventory_2_outlined,
            label: _productCountLabel(productCount),
            backgroundColor: AppColors.softBlue,
            foregroundColor: AppColors.blue,
          ),
        ],
      ],
    );
  }
}

class _SmartScrollBackButton extends StatelessWidget {
  const _SmartScrollBackButton({
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, 0.24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 76),
            child: FloatingActionButton.small(
              heroTag: 'catalog-smart-scroll-back',
              tooltip: 'Remonter',
              elevation: 4,
              highlightElevation: 6,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.premiumLine),
              ),
              onPressed: onPressed,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogContentSliver extends StatelessWidget {
  const _CatalogContentSliver({
    required this.loading,
    required this.error,
    required this.products,
    required this.loadingMore,
    required this.onRetry,
    required this.onOpenProduct,
  });

  final bool loading;
  final Object? error;
  final List<Product> products;
  final bool loadingMore;
  final VoidCallback onRetry;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _sliverWithPagePadding(
        context,
        const ProductSliverGridSkeleton(),
      );
    }

    if (error != null) {
      final friendly = friendlyLoadError(error);
      return _sliverWithPagePadding(
        context,
        SliverToBoxAdapter(
          child: AppStatusPanel(
            icon: Icons.cloud_off_rounded,
            title: friendly.title,
            message: friendly.message,
            action: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return _sliverWithPagePadding(
        context,
        SliverToBoxAdapter(
          child: AppStatusPanel(
            icon: Icons.manage_search_rounded,
            title: 'Aucun résultat',
            message:
                'Aucun produit ne correspond à votre recherche. Essayez avec un autre mot-clé.',
            action: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualiser'),
            ),
          ),
        ),
      );
    }

    return _sliverWithPagePadding(
      context,
      SliverMainAxisGroup(
        slivers: [
          ResponsiveProductSliverGrid(
            products: products,
            onProductTap: onOpenProduct,
          ),
          if (loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: _CatalogLoadingMoreIndicator(),
              ),
            ),
        ],
      ),
      bottom: 96,
    );
  }

  Widget _sliverWithPagePadding(
    BuildContext context,
    Widget sliver, {
    double bottom = 96,
  }) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.crossAxisExtent > 1120
            ? 1120.0
            : constraints.crossAxisExtent;
        final outer = (constraints.crossAxisExtent - pageWidth) / 2;
        final horizontal = constraints.crossAxisExtent >= 720 ? 24.0 : 16.0;
        final inset = outer + horizontal;

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 12, inset, bottom),
          sliver: sliver,
        );
      },
    );
  }
}

class _CatalogLoadingMoreIndicator extends StatelessWidget {
  const _CatalogLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Row(
            key: const ValueKey('loading-more'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Chargement...',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
