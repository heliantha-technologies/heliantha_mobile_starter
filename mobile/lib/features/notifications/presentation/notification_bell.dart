import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/brand_widgets.dart';
import '../providers/notifications_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      notificationsProvider.select(
        (value) => value.maybeWhen(
          data: (result) => result.unread,
          orElse: () => 0,
        ),
      ),
    );

    return TopBarActionPastille(
      tooltip: 'Notifications',
      icon: Icons.notifications_rounded,
      iconColor: const Color(0xFFEA580C),
      backgroundColor: const Color(0xFFFFEDD5),
      gradientColors: const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
      borderColor: const Color(0xFFEA580C).withValues(alpha: 0.32),
      shadowColor: const Color(0xFFEA580C),
      badgeCount: unread,
      onTap: () => context.push('/notifications'),
    );
  }
}
