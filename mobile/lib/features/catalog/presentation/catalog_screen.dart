import 'dart:async';

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
  int _requestVersion = 0;
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
    final requestVersion = ++_requestVersion;
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
        if (requestVersion != _requestVersion) {
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
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) {
      return;
    }

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
      if (mounted) {
        setState(() {
          _products = [...?_products, ...rows];
          _page = nextPage;
          _hasMore = rows.length == _pageSize;
        });
        _loadMoreIfContentIsShort();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(
        context,
        'Nous n’avons pas pu charger plus de produits pour le moment.',
      );
    } finally {
      if (mounted) {
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
        child: ResponsivePagePadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatalogSearchBar(
                controller: _search,
                hasSearch: _hasSearch,
                onClear: _clearSearch,
                onSearch: _loadFirstPage,
              ),
              const SizedBox(height: 10),
              _CategoryFilterBar(
                activeCategory: activeCategory,
                onOpenCategories: _openCategoryPicker,
                onClearCategory: () => _goToCategory(null),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const InfoPill(
                    icon: Icons.verified_rounded,
                    label: 'Produits Heliantha',
                    backgroundColor: AppColors.softLeaf,
                    foregroundColor: AppColors.leaf,
                  ),
                  if (widget.initialCategory != null)
                    InfoPill(
                      icon: Icons.category_rounded,
                      label: activeCategory?.name ?? 'Catégorie sélectionnée',
                      backgroundColor: AppColors.softSun,
                      foregroundColor: AppColors.navy,
                    ),
                  if (!_loading && _error == null)
                    InfoPill(
                      icon: Icons.inventory_2_outlined,
                      label: _productCountLabel(products.length),
                      backgroundColor: AppColors.softBlue,
                      foregroundColor: AppColors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _CatalogContent(
                  loading: _loading,
                  error: _error,
                  products: products,
                  hasMore: _hasMore,
                  loadingMore: _loadingMore,
                  scrollController: _scrollController,
                  onRetry: _loadFirstPage,
                  onOpenProduct: (product) {
                    ref.read(catalogRepositoryProvider).rememberProduct(
                          product,
                        );
                    context.push(
                      '/product/${product.id}',
                      extra: product,
                    );
                  },
                ),
              ),
            ],
          ),
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

    if (context.languages.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Langue',
          icon: const Icon(Icons.language_rounded),
          onSelected: (id) async {
            await ref.read(selectedLanguageIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final language in context.languages)
              PopupMenuItem<int>(
                value: language.id,
                child: Text(language.name),
              ),
          ],
        ),
      );
    }

    if (context.currencies.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Devise',
          icon: const Icon(Icons.payments_rounded),
          onSelected: (id) async {
            await ref.read(selectedCurrencyIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final currency in context.currencies)
              PopupMenuItem<int>(
                value: currency.id,
                child: Text(currency.isoCode),
              ),
          ],
        ),
      );
    }

    return actions.isEmpty ? null : actions;
  }
}

String _productCountLabel(int count) {
  return count == 1 ? '1 produit' : '$count produits';
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.activeCategory,
    required this.onOpenCategories,
    required this.onClearCategory,
  });

  final Category? activeCategory;
  final VoidCallback onOpenCategories;
  final VoidCallback onClearCategory;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: onOpenCategories,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: Text(activeCategory?.name ?? 'Catégories'),
        ),
        if (activeCategory != null)
          InputChip(
            avatar: const Icon(Icons.category_rounded, size: 16),
            label: Text(
              activeCategory!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onDeleted: onClearCategory,
            deleteIcon: const Icon(Icons.close_rounded, size: 18),
            backgroundColor: AppColors.softSun,
            labelStyle: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
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
    return SearchBar(
      controller: controller,
      hintText: 'Rechercher dans le catalogue...',
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
          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.blue),
        ),
      ],
      onSubmitted: (_) => onSearch(),
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

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.loading,
    required this.error,
    required this.products,
    required this.hasMore,
    required this.loadingMore,
    required this.scrollController,
    required this.onRetry,
    required this.onOpenProduct,
  });

  final bool loading;
  final Object? error;
  final List<Product> products;
  final bool hasMore;
  final bool loadingMore;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ProductGridSkeleton(
        itemCount: 6,
        padding: EdgeInsets.only(bottom: 12),
      );
    }

    if (error != null) {
      final friendly = friendlyLoadError(error);
      return SingleChildScrollView(
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
      );
    }

    if (products.isEmpty) {
      return SingleChildScrollView(
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
      );
    }

    return Column(
      children: [
        Expanded(
          child: ResponsiveProductGrid(
            products: products,
            padding: const EdgeInsets.only(bottom: 12),
            controller: scrollController,
            onProductTap: onOpenProduct,
          ),
        ),
        if (loadingMore) ...[
          const SizedBox(height: 8),
          const _CatalogLoadingMoreIndicator(),
        ],
      ],
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
