import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Blocks navigation and interaction while a solar quote is being prepared.
class QuoteGeneratingOverlay extends StatefulWidget {
  const QuoteGeneratingOverlay({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  State<QuoteGeneratingOverlay> createState() => _QuoteGeneratingOverlayState();
}

class _QuoteGeneratingOverlayState extends State<QuoteGeneratingOverlay>
    with SingleTickerProviderStateMixin {
  static const _marine = Color(0xFF0B2239);
  static const _gold = Color(0xFFF4C33D);
  static const _steps = [
    'Analyse de votre profil énergétique',
    'Évaluation de votre gisement solaire',
    'Dimensionnement de votre installation',
    'Préparation de votre devis solaire',
  ];

  late final AnimationController _controller;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != reduceMotion) {
      _reduceMotion = reduceMotion;
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant QuoteGeneratingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.stop();
    _controller.value = 0;
    if (widget.isVisible && _reduceMotion != true) {
      // Stop at the estimated waiting limit; only the real request ends loading.
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    return PopScope(
      canPop: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ModalBarrier(
                dismissible: false,
                color: Color(0x73000000),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(20),
                child: Center(
                  child: SingleChildScrollView(
                    child: AbsorbPointer(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final step = (_controller.value * _steps.length)
                              .floor()
                              .clamp(0, _steps.length - 1)
                              .toInt();
                          final stepText = _reduceMotion == true
                              ? _steps.last
                              : _steps[step];
                          final progress = _reduceMotion == true
                              ? 0.92
                              : 0.08 + _controller.value * 0.84;
                          return Semantics(
                            container: true,
                            liveRegion: true,
                            label: 'Devis en cours. $stepText.',
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _marine.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _gold, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 28,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Transform.rotate(
                                      angle: _controller.value * 20 * math.pi,
                                      child: const Icon(
                                        Icons.wb_sunny_rounded,
                                        size: 48,
                                        color: _gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Votre projet solaire prend forme',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    stepText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value:
                                          progress.clamp(0.0, 0.92).toDouble(),
                                      minHeight: 6,
                                      color: _gold,
                                      backgroundColor: const Color(0xFF294155),
                                      semanticsLabel: 'Préparation du devis',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Merci de patienter, nous préparons une solution '
                                    'adaptée à vos besoins.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFE2E8EF),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
