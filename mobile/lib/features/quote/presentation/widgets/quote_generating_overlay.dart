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
                                    child: SizedBox(
                                      width: 96,
                                      height: 96,
                                      child: CustomPaint(
                                        painter: _SunPainter(
                                          spin: _controller.value * 12,
                                          pulse: (math.sin(_controller.value * 32 * math.pi) + 1) / 2,
                                        ),
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

/// Soleil vectoriel : halo, rayons en rotation, cœur dégradé qui pulse et
/// petit satellite bleu (l'énergie) en orbite.
class _SunPainter extends CustomPainter {
  const _SunPainter({required this.spin, required this.pulse});

  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final coreRadius = radius * (0.34 + 0.025 * pulse);

    // Halo doux
    canvas.drawCircle(
      center,
      radius * (0.78 + 0.06 * pulse),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: 0.55),
            const Color(0xFFFDE68A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Orbite pointillée
    final orbitRadius = radius * 0.86;
    final orbitPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dashCount = 36;
    for (var i = 0; i < dashCount; i += 2) {
      final a0 = (i / dashCount) * 2 * math.pi;
      final a1 = ((i + 1) / dashCount) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        a0,
        a1 - a0,
        false,
        orbitPaint,
      );
    }

    // Rayons solaires dorés
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * 2 * math.pi);
    const rayCount = 12;
    for (var i = 0; i < rayCount; i++) {
      final isLong = i.isEven;
      final inner = coreRadius + radius * 0.08;
      final outer = coreRadius +
          radius * (isLong ? 0.32 : 0.22) +
          (isLong ? radius * 0.03 * pulse : 0);
      final rayPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isLong ? 4.2 : 3
        ..color = (isLong ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24))
            .withValues(alpha: isLong ? 0.95 : 0.75);
      final angle = (i / rayCount) * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(dir * inner, dir * outer, rayPaint);
    }
    canvas.restore();

    // Cœur du soleil avec dégradé et lueur
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius + 2,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFFFF7CC), Color(0xFFFCD34D), Color(0xFFF59E0B)],
          stops: [0, 0.45, 1],
        ).createShader(coreRect),
    );

    // Satellite d'énergie en orbite (rotation orbitale dynamique)
    final satAngle = -spin * 2 * math.pi * 2 - math.pi / 2;
    final satPos = center +
        Offset(math.cos(satAngle), math.sin(satAngle)) * orbitRadius;
    canvas.drawCircle(
      satPos,
      7,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(satPos, 4.5, Paint()..color = const Color(0xFF0EA5E9));
    canvas.drawCircle(satPos, 1.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SunPainter oldDelegate) =>
      oldDelegate.spin != spin || oldDelegate.pulse != pulse;
}
