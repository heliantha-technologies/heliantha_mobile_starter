import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/maintenance/maintenance_gate.dart';
import 'core/maintenance/maintenance_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/catalog/providers/store_context_provider.dart';
import 'features/home/providers/home_provider.dart';
import 'features/notifications/services/fcm_service.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_background.dart';

class HelianthaApp extends ConsumerStatefulWidget {
  const HelianthaApp({super.key});

  @override
  ConsumerState<HelianthaApp> createState() => _HelianthaAppState();
}

class _HelianthaAppState extends ConsumerState<HelianthaApp> {
  bool _fcmStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startFcm());
    });
  }

  Future<void> _startFcm() async {
    if (_fcmStarted) {
      return;
    }
    _fcmStarted = true;

    final service = ref.read(fcmServiceProvider);
    await service.initialize(appRouter);

    final user = await ref.read(currentUserProvider.future);
    if (user != null) {
      await service.registerForCurrentUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(maintenanceProvider, (previous, next) {
      if (next == MaintenanceStatus.available && previous != next) {
        // Reload failed initial reads after reopening; keep local cart and drafts.
        ref.invalidate(currentUserProvider);
        ref.invalidate(storeContextProvider);
        ref.invalidate(homeSlidesProvider);
      }
    });
    ref.listen(currentUserProvider, (previous, next) {
      if (next.valueOrNull != null) {
        unawaited(ref.read(fcmServiceProvider).registerForCurrentUser());
      }
    });

    final storeContext = ref.watch(storeContextProvider).valueOrNull;
    final selectedLanguageId = ref.watch(selectedLanguageIdProvider);
    final language = storeContext?.languageById(
      storeContext.effectiveLanguageId(selectedLanguageId),
    );
    final textDirection =
        language?.isRtl == true ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp.router(
      title: 'Heliantha',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final compactWidth = mediaQuery.size.width <= 600;
        final normalizedMediaQuery = compactWidth
            ? mediaQuery.copyWith(
                padding: mediaQuery.padding.copyWith(left: 0, right: 0),
                viewPadding: mediaQuery.viewPadding.copyWith(left: 0, right: 0),
              )
            : mediaQuery;

        return Directionality(
          textDirection: textDirection,
          child: MediaQuery(
            data: normalizedMediaQuery,
            child: SizedBox.expand(
              child: MaintenanceGate(
                child: HelianthaBackground(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
      theme: AppTheme.light,
    );
  }
}
