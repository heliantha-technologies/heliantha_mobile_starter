import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Arrière-plan 3D temps réel style Daylight Executive / système solaire Heliantha.
///
/// Optimisé 60 FPS :
/// - Isolé dans un [RepaintBoundary] (zéro repaint des cartes au-dessus)
/// - Zéro `BackdropFilter` et zéro allocation lourde dans `paint()`
/// - Pause automatique lorsque l'onglet `/quote` est masqué dans le shell ou
///   lorsque l'utilisateur active la réduction des animations.
class SolarSystem3DBackground extends StatefulWidget {
  const SolarSystem3DBackground({
    super.key,
    this.tiltOffset = Offset.zero,
    this.focusColor,
  });

  /// Décalage normalisé `[-1, 1]` pour le parallaxe doux (souris sur desktop).
  final Offset tiltOffset;

  /// Couleur d'accentuation optionnelle (carte survolée).
  final Color? focusColor;

  @override
  State<SolarSystem3DBackground> createState() =>
      _SolarSystem3DBackgroundState();
}

class _SolarSystem3DBackgroundState extends State<SolarSystem3DBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  GoRouterDelegate? _routerDelegate;
  bool _isQuoteVisible = true;
  bool _disableAnimations = false;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;

    final nextDelegate = GoRouter.maybeOf(context)?.routerDelegate;
    if (_routerDelegate != nextDelegate) {
      _routerDelegate?.removeListener(_onRouteChanged);
      _routerDelegate = nextDelegate;
      _routerDelegate?.addListener(_onRouteChanged);
    }
    _updateRouteVisibility();
    _syncAnimation();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final wasVisible = _isQuoteVisible;
    _updateRouteVisibility();
    if (wasVisible != _isQuoteVisible) {
      _syncAnimation();
    }
  }

  void _updateRouteVisibility() {
    final delegate = _routerDelegate;
    if (delegate == null) {
      _isQuoteVisible = true;
      return;
    }
    final path = delegate.currentConfiguration.uri.path;
    _isQuoteVisible = path == '/quote' || path.startsWith('/quote/');
  }

  void _syncAnimation() {
    final shouldRun = _isQuoteVisible && _tickerEnabled && !_disableAnimations;
    if (shouldRun) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_disableAnimations && _controller.value == 0.0) {
        // Pose fixe harmonieuse si les animations système sont désactivées.
        _controller.value = 0.12;
      }
    }
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(end: widget.tiltOffset),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (context, smoothTilt, _) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  isComplex: true,
                  willChange: _controller.isAnimating,
                  painter: _SolarSystem3DPainter(
                    phase: _controller.value,
                    tiltOffset: smoothTilt,
                    focusColor: widget.focusColor,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SolarSystem3DPainter extends CustomPainter {
  _SolarSystem3DPainter({
    required this.phase,
    required this.tiltOffset,
    this.focusColor,
  });

  final double phase;
  final Offset tiltOffset;
  final Color? focusColor;

  static final List<_StarSpec> _stars = List.generate(60, (i) {
    final rng = math.Random(42 + i * 19);
    return _StarSpec(
      nx: rng.nextDouble(),
      ny: rng.nextDouble(),
      radius: 0.70 + rng.nextDouble() * 1.40,
      baseAlpha: 0.08 + rng.nextDouble() * 0.16,
      twinkleSpeed: (i % 4) + 2,
      twinklePhase: rng.nextDouble() * math.pi * 2,
      depth: 0.4 + rng.nextDouble() * 0.8,
      tint: i % 5 == 0
          ? const Color(0xFFD97706)
          : const Color(0xFF0A6097),
    );
  });

  // Vitesses entières pour boucle infinie sans coupure à phase = 1.0 -> 0.0.
  static const _orbits = <_OrbitSpec>[
    _OrbitSpec(
      radiusFactor: 0.22,
      tiltX: 1.08,
      tiltZ: -0.24,
      speed: 3,
      angleOffset: 0.75,
      planetRadius: 8.0,
      planetColor: Color(0xFF0284C7),
      orbitColor: Color(0xFF0A6097),
      focusColor: Color(0xFF0A6097),
      hasRing: false,
      hasMoon: false,
    ),
    _OrbitSpec(
      radiusFactor: 0.31,
      tiltX: 1.14,
      tiltZ: -0.20,
      speed: 2,
      angleOffset: 2.35,
      planetRadius: 10.0,
      planetColor: Color(0xFFF59E0B),
      orbitColor: Color(0xFFD97706),
      focusColor: Color(0xFFB45309),
      hasRing: false,
      hasMoon: true,
    ),
    _OrbitSpec(
      radiusFactor: 0.42,
      tiltX: 1.12,
      tiltZ: -0.26,
      speed: 2,
      angleOffset: 4.10,
      planetRadius: 12.0,
      planetColor: Color(0xFF059669),
      orbitColor: Color(0xFF0A6097),
      focusColor: Color(0xFF047857),
      hasRing: false,
      hasMoon: true,
    ),
    _OrbitSpec(
      radiusFactor: 0.54,
      tiltX: 1.15,
      tiltZ: -0.22,
      speed: 1,
      angleOffset: 5.45,
      planetRadius: 13.5,
      planetColor: Color(0xFFD97706),
      orbitColor: Color(0xFFD97706),
      focusColor: Color(0xFFD97706),
      hasRing: true,
      hasMoon: false,
    ),
    _OrbitSpec(
      radiusFactor: 0.65,
      tiltX: 1.10,
      tiltZ: -0.25,
      speed: 1,
      angleOffset: 1.35,
      planetRadius: 9.0,
      planetColor: Color(0xFF0A6097),
      orbitColor: Color(0xFF0A6097),
      focusColor: Color(0xFF0A6097),
      hasRing: false,
      hasMoon: false,
    ),
  ];

  // Tampons pré-alloués pour éviter toute allocation par frame.
  final List<double> _rotBuf = List<double>.filled(3, 0);
  final List<double> _projBuf = List<double>.filled(2, 0);
  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  Offset _project3D(
    double x,
    double y,
    double z,
    Offset center,
    double focal,
  ) {
    final persp = focal / (focal + z);
    _projBuf[0] = persp;
    _projBuf[1] = z;
    return Offset(center.dx + x * persp, center.dy + y * persp);
  }

  void _rotate3D(double x, double y, double tiltX, double tiltZ) {
    final effTiltX = tiltX + tiltOffset.dy * 0.09;
    final effTiltZ = tiltZ + tiltOffset.dx * 0.08;
    final y1 = y * math.cos(effTiltX);
    final z1 = y * math.sin(effTiltX);
    final cosZ = math.cos(effTiltZ);
    final sinZ = math.sin(effTiltZ);
    _rotBuf[0] = x * cosZ - y1 * sinZ;
    _rotBuf[1] = x * sinZ + y1 * cosZ;
    _rotBuf[2] = z1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * 0.50 + tiltOffset.dx * 10.0,
      size.height * 0.49 + tiltOffset.dy * 8.0,
    );
    final maxDim = math.max(size.width, size.height);
    final minDim = math.min(size.width, size.height);
    final baseRadius = minDim * 0.90;
    final focal = maxDim * 1.45;

    // 1. Fond Daylight Executive (Bleu Glacier / Perle lumineux + brume solaire)
    _fillPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFF6FAFF),
        Color(0xFFEAF3FC),
        Color(0xFFD4E5F7),
      ],
      stops: [0.0, 0.50, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _fillPaint);
    _fillPaint.shader = null;

    _fillPaint.shader = RadialGradient(
      center: const Alignment(0.0, -0.04),
      radius: 0.72,
      colors: [
        const Color(0xFFFDE68A).withValues(alpha: 0.42),
        const Color(0xFFBAE6FD).withValues(alpha: 0.28),
        const Color(0xFFEAF3FC).withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _fillPaint);
    _fillPaint.shader = null;

    // Halo subtil de la carte survolée (interaction vivante)
    if (focusColor != null) {
      _fillPaint.shader = RadialGradient(
        colors: [
          focusColor!.withValues(alpha: 0.14),
          focusColor!.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.52));
      canvas.drawCircle(center, baseRadius * 0.52, _fillPaint);
      _fillPaint.shader = null;
    }

    // 2. Photons discrets avec parallaxe doux
    for (final s in _stars) {
      final px = (s.nx * size.width - tiltOffset.dx * 8.0 * s.depth) %
          math.max(1.0, size.width);
      final py = (s.ny * size.height - tiltOffset.dy * 6.0 * s.depth) %
          math.max(1.0, size.height);
      final twinkle = 0.72 +
          0.28 *
              math.sin(
                phase * math.pi * 2 * s.twinkleSpeed + s.twinklePhase,
              );
      _fillPaint.color = s.tint.withValues(alpha: s.baseAlpha * twinkle);
      canvas.drawCircle(Offset(px, py), s.radius, _fillPaint);
    }

    // 3. Réticule architectural / ingénierie solaire
    _strokePaint
      ..strokeWidth = 1.0
      ..color = const Color(0xFF0A6097).withValues(alpha: 0.11);
    for (final f in const [0.22, 0.36, 0.52]) {
      canvas.drawCircle(center, baseRadius * f, _strokePaint);
    }

    // 4. Orbites 3D inclinées (segmentées arrière / avant pour l'effet de profondeur)
    for (final orb in _orbits) {
      final r = baseRadius * orb.radiusFactor;
      final backPath = Path();
      final frontPath = Path();
      var backStarted = false;
      var frontStarted = false;
      const steps = 84;
      for (var i = 0; i <= steps; i++) {
        final a = (i / steps) * math.pi * 2;
        _rotate3D(r * math.cos(a), r * math.sin(a), orb.tiltX, orb.tiltZ);
        final p = _project3D(_rotBuf[0], _rotBuf[1], _rotBuf[2], center, focal);
        if (_rotBuf[2] >= 0) {
          if (!backStarted) {
            backPath.moveTo(p.dx, p.dy);
            backStarted = true;
          } else {
            backPath.lineTo(p.dx, p.dy);
          }
          frontStarted = false;
        } else {
          if (!frontStarted) {
            frontPath.moveTo(p.dx, p.dy);
            frontStarted = true;
          } else {
            frontPath.lineTo(p.dx, p.dy);
          }
          backStarted = false;
        }
      }
      final isHighlighted =
          focusColor != null && focusColor == orb.focusColor;
      _strokePaint
        ..strokeWidth = isHighlighted ? 1.5 : 1.25
        ..color = orb.orbitColor.withValues(alpha: isHighlighted ? 0.30 : 0.18);
      canvas.drawPath(backPath, _strokePaint);

      _strokePaint
        ..strokeWidth = isHighlighted ? 2.0 : 1.65
        ..color = orb.orbitColor.withValues(alpha: isHighlighted ? 0.56 : 0.38);
      canvas.drawPath(frontPath, _strokePaint);
    }

    // 5. Tri Z (Soleil + Planètes)
    final drawItems = <_DepthItem>[
      _DepthItem(
        z: 0.0,
        draw: () => _drawSun(canvas, center, minDim),
      ),
    ];

    for (final orb in _orbits) {
      final r = baseRadius * orb.radiusFactor;
      final a = orb.angleOffset + phase * math.pi * 2 * orb.speed;
      _rotate3D(r * math.cos(a), r * math.sin(a), orb.tiltX, orb.tiltZ);
      final px = _rotBuf[0];
      final py = _rotBuf[1];
      final pz = _rotBuf[2];
      final screenPos = _project3D(px, py, pz, center, focal);
      final scale = _projBuf[0];

      final trailPath = Path();
      for (var t = 0; t <= 14; t++) {
        final ta = a - t * 0.045;
        _rotate3D(r * math.cos(ta), r * math.sin(ta), orb.tiltX, orb.tiltZ);
        final tp =
            _project3D(_rotBuf[0], _rotBuf[1], _rotBuf[2], center, focal);
        if (t == 0) {
          trailPath.moveTo(tp.dx, tp.dy);
        } else {
          trailPath.lineTo(tp.dx, tp.dy);
        }
      }

      drawItems.add(
        _DepthItem(
          z: pz,
          draw: () {
            _strokePaint
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 2.4 * scale
              ..color = orb.planetColor.withValues(alpha: 0.46);
            canvas.drawPath(trailPath, _strokePaint);
            _drawPlanet(
              canvas,
              screenPos,
              center,
              orb.planetRadius * scale,
              orb.planetColor,
              orb.hasRing,
              orb.hasMoon,
            );
          },
        ),
      );
    }

    drawItems.sort((a, b) => b.z.compareTo(a.z));
    for (final item in drawItems) {
      item.draw();
    }
  }

  void _drawSun(Canvas canvas, Offset center, double minDim) {
    final pulse = (math.sin(phase * math.pi * 2 * 6) + 1) * 0.5;
    final sunRadius = (minDim * 0.125).clamp(38.0, 62.0);

    // Couronne solaire chaude
    _fillPaint.shader = RadialGradient(
      colors: [
        const Color(0xFFF59E0B).withValues(alpha: 0.34 + pulse * 0.08),
        const Color(0xFFEA580C).withValues(alpha: 0.12),
        const Color(0xFFF59E0B).withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: sunRadius * 3.1));
    canvas.drawCircle(center, sunRadius * 3.1, _fillPaint);
    _fillPaint.shader = null;

    // Double anneau architectural autour du Soleil
    _strokePaint
      ..strokeWidth = 1.25
      ..color = const Color(0xFF0A6097).withValues(alpha: 0.40);
    canvas.drawCircle(center, sunRadius * 1.48, _strokePaint);

    _strokePaint
      ..strokeWidth = 1.1
      ..color = const Color(0xFFD97706).withValues(alpha: 0.38);
    canvas.drawCircle(center, sunRadius * 1.72, _strokePaint);

    // Rayons solaires en rotation lente
    for (var i = 0; i < 16; i++) {
      final a = (i / 16) * math.pi * 2 + phase * math.pi * 2;
      final isLong = i.isEven;
      final inner = sunRadius * 1.12;
      final outer = sunRadius * (isLong ? 1.92 : 1.56);
      _strokePaint
        ..strokeWidth = isLong ? 1.8 : 1.1
        ..strokeCap = StrokeCap.round
        ..color =
            const Color(0xFFD97706).withValues(alpha: isLong ? 0.60 : 0.32);
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * inner,
        center + Offset(math.cos(a), math.sin(a)) * outer,
        _strokePaint,
      );
    }

    // Sphère solaire volumétrique
    final sunRect = Rect.fromCircle(center: center, radius: sunRadius);
    _fillPaint.shader = const RadialGradient(
      center: Alignment(-0.28, -0.28),
      colors: [
        Color(0xFFFFFBEB),
        Color(0xFFFDE047),
        Color(0xFFF59E0B),
        Color(0xFFD97706),
      ],
      stops: [0.0, 0.34, 0.74, 1.0],
    ).createShader(sunRect);
    canvas.drawCircle(center, sunRadius, _fillPaint);
    _fillPaint.shader = null;
  }

  void _drawPlanet(
    Canvas canvas,
    Offset pos,
    Offset sunCenter,
    double r,
    Color baseColor,
    bool hasRing,
    bool hasMoon,
  ) {
    // Halo atmosphérique
    _fillPaint.shader = RadialGradient(
      colors: [
        baseColor.withValues(alpha: 0.30),
        baseColor.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: pos, radius: r * 1.8));
    canvas.drawCircle(pos, r * 1.8, _fillPaint);
    _fillPaint.shader = null;

    if (hasRing) {
      _drawSaturnRing(canvas, pos, r, backHalf: true);
    }

    // Éclairage directionnel orienté vers le Soleil central
    final toSun = sunCenter - pos;
    final dist = toSun.distance == 0 ? 1.0 : toSun.distance;
    final align = Alignment(
      (toSun.dx / dist) * 0.55,
      (toSun.dy / dist) * 0.55,
    );
    final rect = Rect.fromCircle(center: pos, radius: r);
    _fillPaint.shader = RadialGradient(
      center: align,
      radius: 1.1,
      colors: [
        Colors.white,
        baseColor,
        Color.lerp(baseColor, const Color(0xFF0B2239), 0.58)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);
    canvas.drawCircle(pos, r, _fillPaint);
    _fillPaint.shader = null;

    if (hasRing) {
      _drawSaturnRing(canvas, pos, r, backHalf: false);
    }

    if (hasMoon) {
      final ma = phase * math.pi * 2 * 6;
      final moonPos =
          pos + Offset(math.cos(ma) * r * 1.85, math.sin(ma) * r * 0.72);
      _fillPaint.color = const Color(0xFF0B2239);
      canvas.drawCircle(moonPos, r * 0.28, _fillPaint);
    }
  }

  void _drawSaturnRing(
    Canvas canvas,
    Offset pos,
    double r, {
    required bool backHalf,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-0.35);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 3.4,
      height: r * 1.05,
    );
    _strokePaint
      ..strokeWidth = r * 0.36
      ..color =
          const Color(0xFFD97706).withValues(alpha: backHalf ? 0.38 : 0.74);
    canvas.drawArc(
      rect,
      backHalf ? math.pi : 0.0,
      math.pi,
      false,
      _strokePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SolarSystem3DPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.tiltOffset != tiltOffset ||
      oldDelegate.focusColor != focusColor;
}

class _StarSpec {
  const _StarSpec({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.baseAlpha,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.depth,
    required this.tint,
  });

  final double nx;
  final double ny;
  final double radius;
  final double baseAlpha;
  final int twinkleSpeed;
  final double twinklePhase;
  final double depth;
  final Color tint;
}

class _OrbitSpec {
  const _OrbitSpec({
    required this.radiusFactor,
    required this.tiltX,
    required this.tiltZ,
    required this.speed,
    required this.angleOffset,
    required this.planetRadius,
    required this.planetColor,
    required this.orbitColor,
    required this.focusColor,
    required this.hasRing,
    required this.hasMoon,
  });

  final double radiusFactor;
  final double tiltX;
  final double tiltZ;
  final int speed;
  final double angleOffset;
  final double planetRadius;
  final Color planetColor;
  final Color orbitColor;
  final Color focusColor;
  final bool hasRing;
  final bool hasMoon;
}

class _DepthItem {
  const _DepthItem({required this.z, required this.draw});
  final double z;
  final VoidCallback draw;
}
