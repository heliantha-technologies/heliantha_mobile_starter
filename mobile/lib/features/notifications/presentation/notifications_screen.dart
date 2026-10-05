import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/notification_item.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Notifications',
        showBack: true,
        backFallbackLocation: '/account',
      ),
      body: notifications.when(
        loading: () => const _NotificationsSkeleton(),
        error: (error, __) {
          final friendly = friendlyLoadError(error);
          return ResponsivePagePadding(
            child: AppStatusPanel(
              icon: Icons.notifications_off_outlined,
              title: friendly.title,
              message: friendly.message,
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(notificationsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
          );
        },
        data: (result) {
          if (result.items.isEmpty) {
            return const ResponsivePagePadding(
              child: AppStatusPanel(
                icon: Icons.notifications_none_rounded,
                title: 'Aucune notification',
                message:
                    'Vos alertes de commande et de disponibilité apparaîtront ici.',
              ),
            );
          }

          return SingleChildScrollView(
            child: ResponsivePagePadding(
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationsHeader(
                    unread: result.unread,
                    total: result.items.length,
                  ),
                  const SizedBox(height: 14),
                  for (final item in result.items) ...[
                    _NotificationTile(
                      item: item,
                      onTap: () {
                        unawaited(
                          ref
                              .read(notificationsRepositoryProvider)
                              .markRead(item.id)
                              .catchError((error) {
                            debugPrint('Notification mark-read error: $error');
                          }),
                        );
                        ref.invalidate(notificationsProvider);
                        _openNotification(context, item);
                      },
                    ),
                    if (item != result.items.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openNotification(BuildContext context, NotificationItem item) {
    if (item.orderId != null &&
        (item.type == 'ORDER_STATUS' || item.type == 'PAYMENT_STATUS')) {
      context.push('/orders/${item.orderId}');
      return;
    }
    if (item.productId != null && item.type == 'FAVORITE_BACK_IN_STOCK') {
      context.push('/product/${item.productId}');
    }
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unread,
    required this.total,
  });

  final int unread;
  final int total;

  @override
  Widget build(BuildContext context) {
    final subtitle = unread > 0
        ? '$unread nouvelle${unread > 1 ? 's' : ''} notification${unread > 1 ? 's' : ''}'
        : 'Toutes vos notifications sont à jour';

    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.navy,
      borderColor: AppColors.navy,
      shadow: true,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.sun,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centre de notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFD5E2EC),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.sun,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              '$total',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = _colorFor(item.type);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.006 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: widget.onTap,
            splashColor: color.withValues(alpha: 0.08),
            highlightColor: color.withValues(alpha: 0.04),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.isRead ? AppColors.surface : const Color(0xFFFDFBF2),
                    AppColors.surfaceGlow,
                    AppColors.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: item.isRead
                      ? (_hovered ? AppColors.blue : AppColors.premiumLine)
                      : AppColors.sun,
                  width: item.isRead ? 1 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(
                      alpha: _hovered ? 0.11 : 0.065,
                    ),
                    blurRadius: _hovered ? 22 : 16,
                    offset: Offset(0, _hovered ? 10 : 7),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(
                    icon: _iconFor(item.type),
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                    size: 48,
                    iconSize: 23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _labelFor(item.type),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (!item.isRead) const _UnreadPill(),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                    height: 1.18,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.muted.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _formatDate(item.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? AppColors.softBlue
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.blue,
                      size: 20,
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return "Aujourd'hui à ${DateFormat('HH:mm').format(local)}";
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Hier à ${DateFormat('HH:mm').format(local)}';
    }

    return DateFormat('dd/MM/yyyy à HH:mm').format(local);
  }

  String _labelFor(String type) {
    return switch (type) {
      'PAYMENT_STATUS' => 'Paiement',
      'FAVORITE_BACK_IN_STOCK' => 'Favori',
      'ORDER_STATUS' => 'Commande',
      _ => 'Notification',
    };
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'PAYMENT_STATUS' => Icons.payments_outlined,
      'FAVORITE_BACK_IN_STOCK' => Icons.favorite_border_rounded,
      'ORDER_STATUS' => Icons.local_shipping_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }

  Color _colorFor(String type) {
    return switch (type) {
      'PAYMENT_STATUS' => AppColors.leaf,
      'FAVORITE_BACK_IN_STOCK' => AppColors.danger,
      'ORDER_STATUS' => AppColors.blue,
      _ => AppColors.navy,
    };
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sun,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Nouveau',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePagePadding(
        bottom: 96,
        child: Column(
          children: [
            const _SkeletonCard(height: 82),
            const SizedBox(height: 14),
            for (var i = 0; i < 5; i++) ...[
              const _NotificationSkeletonTile(),
              if (i != 4) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationSkeletonTile extends StatelessWidget {
  const _NotificationSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonCard(width: 48, height: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonCard(width: 86, height: 12),
                const SizedBox(height: 8),
                const _SkeletonCard(height: 15),
                const SizedBox(height: 7),
                const _SkeletonCard(height: 12),
                const SizedBox(height: 5),
                const _SkeletonCard(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}
