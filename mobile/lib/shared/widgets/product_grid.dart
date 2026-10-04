import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'product_card.dart';

class ResponsiveProductGrid extends StatelessWidget {
  const ResponsiveProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.controller,
  });

  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final spacing = constraints.maxWidth < 420 ? 10.0 : 14.0;
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final extent = _extentFor(cellWidth);

        return GridView.builder(
          controller: controller,
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: extent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            );
          },
        );
      },
    );
  }
}

class ResponsiveProductSliverGrid extends StatelessWidget {
  const ResponsiveProductSliverGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  final List<Product> products;
  final ValueChanged<Product> onProductTap;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.crossAxisExtent);
        final spacing = constraints.crossAxisExtent < 420 ? 10.0 : 14.0;
        final cellWidth =
            (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: _extentFor(cellWidth),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final product = products[index];
              return ProductCard(
                product: product,
                onTap: () => onProductTap(product),
              );
            },
            childCount: products.length,
          ),
        );
      },
    );
  }
}

class ProductSliverGridSkeleton extends StatelessWidget {
  const ProductSliverGridSkeleton({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.crossAxisExtent);
        final spacing = constraints.crossAxisExtent < 420 ? 10.0 : 14.0;
        final cellWidth =
            (constraints.crossAxisExtent - spacing * (columns - 1)) / columns;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: _extentFor(cellWidth),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => const _ProductCardSkeleton(),
            childCount: itemCount,
          ),
        );
      },
    );
  }
}

class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final spacing = constraints.maxWidth < 420 ? 10.0 : 14.0;
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final extent = _extentFor(cellWidth);

        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: extent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemBuilder: (_, __) => const _ProductCardSkeleton(),
        );
      },
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF7FBFD),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.premiumLine),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _SkeletonBox(width: double.infinity),
            ),
            const SizedBox(height: 10),
            const _SkeletonBox(width: double.infinity, height: 15),
            const SizedBox(height: 7),
            const _SkeletonBox(width: 92, height: 18),
            const SizedBox(height: 10),
            Row(
              children: const [
                Expanded(child: _SkeletonBox(height: 32)),
                SizedBox(width: 8),
                _SkeletonBox(width: 38, height: 38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

int _columnsFor(double width) {
  if (width >= 980) {
    return 4;
  }
  if (width >= 660) {
    return 3;
  }
  return 2;
}

double _extentFor(double cellWidth) {
  if (cellWidth < 156) {
    return 312;
  }
  if (cellWidth < 190) {
    return 322;
  }
  if (cellWidth < 240) {
    return 332;
  }
  return 342;
}
