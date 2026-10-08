import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'maintenance_provider.dart';

class MaintenanceGate extends ConsumerStatefulWidget {
  const MaintenanceGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends ConsumerState<MaintenanceGate>
    with WidgetsBindingObserver {
  late MaintenanceNotifier _notifier;
  bool _hasOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ref.read(maintenanceProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.resume();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifier.resume();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _notifier.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifier.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final available = state == MaintenanceStatus.available;
    _hasOpened = _hasOpened || available;
    return Stack(fit: StackFit.expand, children: [
      if (_hasOpened)
        Offstage(
          offstage: !available,
          child: TickerMode(enabled: available, child: widget.child),
        ),
      if (!available)
        MaintenanceScreen(status: state, onRetry: _notifier.retry),
    ]);
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen(
      {super.key, required this.status, required this.onRetry});
  final MaintenanceStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0B2239);
    const gold = Color(0xFFF4C33D);
    final checking = status == MaintenanceStatus.checking;
    final maintenance = status == MaintenanceStatus.maintenance;
    return Scaffold(
      backgroundColor: navy,
      body: DecoratedBox(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [Color(0xFF214966), navy],
        )),
        child: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: gold.withValues(alpha: .25)),
                ),
                child:
                    const Icon(Icons.wb_sunny_outlined, size: 52, color: gold),
              ),
              const SizedBox(height: 24),
              const Text('HELIANTHA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 4,
                  )),
              const SizedBox(height: 28),
              Text(
                checking
                    ? 'Bienvenue'
                    : maintenance
                        ? 'Une pause pour mieux\nvous accompagner'
                        : 'Retrouvons la connexion',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
              const SizedBox(height: 16),
              Text(
                checking
                    ? 'Connexion à votre espace solaire…'
                    : maintenance
                        ? 'Nous améliorons votre expérience solaire.\nNous serons bientôt de retour.'
                        : 'Le service est momentanément inaccessible.\nNous réessayons automatiquement.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFC4D5E2), fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 28),
              if (checking)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(color: gold, strokeWidth: 2))
              else ...[
                if (maintenance)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: gold.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(24)),
                    child: const Text('Maintenance en cours',
                        style: TextStyle(color: gold)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: navy,
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () async {
                        try {
                          if (await launchUrl(AppConfig.supportWhatsAppUri(),
                              mode: LaunchMode.externalApplication)) {
                            return;
                          }
                        } catch (_) {}
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              'Contactez-nous au ${AppConfig.supportWhatsAppDisplay}'),
                        ));
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contacter un conseiller'),
                    )),
                TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Vérifier la disponibilité')),
                const Text('Retour automatique dès la réouverture.',
                    style: TextStyle(color: Color(0xFFA9BDCC), fontSize: 12)),
              ],
            ]),
          ),
        ))),
      ),
    );
  }
}
