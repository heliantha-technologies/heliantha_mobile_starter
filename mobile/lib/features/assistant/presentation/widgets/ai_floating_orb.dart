import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_chat_bottom_sheet.dart';

/// Orbe flottant luxueux inspiré d'Apple Intelligence / Siri
/// Déplaçable librement par l'utilisateur (Drag & Drop avec magnétisme aux bords)
/// et animé avec un clignotement radar ("Je suis là !") pour capter le regard.
class AiFloatingOrb extends StatefulWidget {
  const AiFloatingOrb({
    super.key,
    this.contextPrompt,
    this.initialQuestion,
    this.initialBottomMargin,
    this.tooltip = 'Conseiller Solaire IA',
  });

  final String? contextPrompt;
  final String? initialQuestion;
  final double? initialBottomMargin;
  final String tooltip;

  @override
  State<AiFloatingOrb> createState() => _AiFloatingOrbState();
}

class _AiFloatingOrbState extends State<AiFloatingOrb>
    with TickerProviderStateMixin {
  static const double _orbSize = 58.0;

  // Animation de clignotement / brillance (Blink de présence)
  late final AnimationController _blinkController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _sparkleScaleAnimation;

  // Animation de radar / onde expansive ("Je suis là !")
  late final AnimationController _radarController;
  late final Animation<double> _radarScaleAnimation;
  late final Animation<double> _radarOpacityAnimation;

  // Animation d'aimantation aux bords (Snap to edge)
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  // Positionnement libre en pixels
  double? _x;
  double? _y;
  bool _isDragging = false;
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Contrôleur de clignotement lumineux (cycle respirant continu de 1.4s)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.95).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOutSine,
      ),
    );

    _sparkleScaleAnimation = Tween<double>(begin: 0.92, end: 1.14).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOutBack,
      ),
    );

    // 2. Contrôleur d'onde radar expansive ("Bip... Je suis là !")
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _radarScaleAnimation = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: Curves.easeOutQuad,
      ),
    );

    _radarOpacityAnimation = Tween<double>(begin: 0.70, end: 0.0).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: Curves.easeOutQuad,
      ),
    );

    // 3. Contrôleur de retour élastique sur le bord (Snap)
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _x = _snapAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _radarController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  void _openChat() {
    HapticFeedback.mediumImpact();
    AiChatBottomSheet.show(
      context,
      contextPrompt: widget.contextPrompt,
      initialQuestion: widget.initialQuestion,
    );
  }

  /// Aimante doucement le bouton vers le bord gauche ou droit le plus proche
  void _snapToNearestEdge(double parentWidth) {
    if (_x == null) return;

    final middle = parentWidth / 2.0;
    final targetX = (_x! + _orbSize / 2.0 < middle)
        ? 14.0
        : (parentWidth - _orbSize - 14.0);

    _snapAnimation = Tween<double>(begin: _x!, end: targetX).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutCubic,
      ),
    );
    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        final parentHeight = constraints.maxHeight;

        // Initialisation de la position par défaut (en bas à droite)
        if (_x == null || _y == null) {
          _x = parentWidth - _orbSize - 16.0;
          final bottomMargin = widget.initialBottomMargin ?? 22.0;
          _y = parentHeight - _orbSize - bottomMargin;
        }

        // Sécurisation dans les limites de l'écran
        _x = _x!.clamp(8.0, math.max(8.0, parentWidth - _orbSize - 8.0));
        _y = _y!.clamp(8.0, math.max(8.0, parentHeight - _orbSize - 8.0));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _x,
              top: _y,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _snapController.stop();
                  _isDragging = true;
                  _dragDistance = 0.0;
                  HapticFeedback.selectionClick();
                  setState(() {});
                },
                onPanUpdate: (details) {
                  _dragDistance += details.delta.distance;
                  setState(() {
                    _x = (_x! + details.delta.dx).clamp(
                      8.0,
                      parentWidth - _orbSize - 8.0,
                    );
                    _y = (_y! + details.delta.dy).clamp(
                      8.0,
                      parentHeight - _orbSize - 8.0,
                    );
                  });
                },
                onPanEnd: (details) {
                  _isDragging = false;
                  setState(() {});
                  // Si l'utilisateur n'a fait qu'un tap rapide (< 6 px)
                  if (_dragDistance < 6.0) {
                    _openChat();
                  } else {
                    _snapToNearestEdge(parentWidth);
                  }
                },
                onTap: _openChat,
                child: AnimatedScale(
                  scale: _isDragging ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _blinkController,
                      _radarController,
                    ]),
                    builder: (context, child) {
                      final glow = _glowAnimation.value;
                      final sparkleScale = _sparkleScaleAnimation.value;
                      final radarScale = _radarScaleAnimation.value;
                      final radarOpacity = _radarOpacityAnimation.value;

                      return SizedBox(
                        width: _orbSize,
                        height: _orbSize,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // 1. Onde radar expansive clignotante ("Je suis là !")
                            Transform.scale(
                              scale: radarScale,
                              child: Container(
                                width: _orbSize,
                                height: _orbSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: radarOpacity),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),

                            // 2. Halo lumineux doré pulsant Apple Intelligence
                            Container(
                              width: _orbSize,
                              height: _orbSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  // Halo clignotant doré intense
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: glow * 0.85),
                                    blurRadius: 16 + (glow * 14),
                                    spreadRadius: 2 + (glow * 4),
                                  ),
                                  // Assise Bleu Nuit profonde
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: _isDragging ? 0.6 : 0.45),
                                    blurRadius: _isDragging ? 22 : 14,
                                    offset: Offset(0, _isDragging ? 10 : 5),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Corps principal de l'orbe en Bleu Nuit satiné
                            Container(
                              width: _orbSize,
                              height: _orbSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0F172A),
                                    Color(0xFF1E293B),
                                    Color(0xFF0F172A),
                                  ],
                                ),
                                border: Border.all(
                                  color: Color.lerp(
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFFDE68A),
                                    glow,
                                  )!,
                                  width: 1.6,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Reflet satiné supérieur style verre Apple
                                  Positioned(
                                    top: 4,
                                    child: Container(
                                      width: 28,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withValues(alpha: 0.28),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Icône étincelle scintillante
                                  Transform.scale(
                                    scale: sparkleScale,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color.lerp(
                                        const Color(0xFFF59E0B),
                                        const Color(0xFFFDE047),
                                        glow,
                                      ),
                                      size: 26,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4. Pastille verte pulsante "En ligne • Je suis là"
                            Positioned(
                              top: 1,
                              right: 1,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.7),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
