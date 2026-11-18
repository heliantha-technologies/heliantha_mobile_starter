import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_vector_icons.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../assistant/presentation/widgets/ai_floating_orb.dart';
import 'widgets/solar_system_3d_background.dart';

class QuoteProjectSelectorScreen extends StatefulWidget {
  const QuoteProjectSelectorScreen({super.key});

  @override
  State<QuoteProjectSelectorScreen> createState() =>
      _QuoteProjectSelectorScreenState();
}

class _QuoteProjectSelectorScreenState
    extends State<QuoteProjectSelectorScreen> {
  static const _projects = <_QuoteProject>[
    _QuoteProject(
      title: 'Pompage solaire',
      tag: 'Irrigation',
      description: 'Forage, bassin & irrigation continue',
      metaLabel: 'Débit / HMT ou puissance CV',
      buttonLabel: 'Estimer mon pompage',
      svgIcon: AppVectorIcons.colorPump,
      accentColor: Color(0xFF0A6097),
      tintBackground: Color(0xFFE0F2FE),
      iconGradient: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
      projectType: 'pompage',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Site sans réseau',
      tag: 'Off-Grid',
      description: 'Autonomie électrique totale',
      metaLabel: 'Sites isolés & refuges',
      buttonLabel: 'Bientôt disponible',
      svgIcon: AppVectorIcons.colorOffGridHome,
      accentColor: Color(0xFF4338CA),
      tintBackground: Color(0xFFE0E7FF),
      iconGradient: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
      enabled: false,
    ),
    _QuoteProject(
      title: 'Réduire ma facture',
      tag: 'Photovoltaïque',
      description: 'Autoconsommation & économies',
      metaLabel: 'Compteur, réseau & kWc',
      buttonLabel: 'Estimer mes économies',
      svgIcon: AppVectorIcons.colorSolarPanel,
      accentColor: Color(0xFFB45309),
      tintBackground: Color(0xFFFEF3C7),
      iconGradient: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
      projectType: 'autoconsommation',
      enabled: true,
      featured: true,
    ),
    _QuoteProject(
      title: 'Solaire avec batteries',
      tag: 'Hybride 24/7',
      description: 'Stockage Lithium jour & nuit',
      metaLabel: 'Autonomie & secours coupures',
      buttonLabel: 'Estimer mon installation',
      svgIcon: AppVectorIcons.colorBattery,
      accentColor: Color(0xFF047857),
      tintBackground: Color(0xFFD1FAE5),
      iconGradient: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
      projectType: 'hybride',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Chauffage solaire',
      tag: 'Thermique',
      description: 'Eau chaude sanitaire solaire',
      metaLabel: 'Chauffe-eau & collectif',
      buttonLabel: 'Bientôt disponible',
      svgIcon: AppVectorIcons.colorSolarThermal,
      accentColor: Color(0xFFC2410C),
      tintBackground: Color(0xFFFFEDD5),
      iconGradient: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
      enabled: false,
    ),
    _QuoteProject(
      title: 'Recharge électrique',
      tag: 'Borne VE',
      description: 'Borne pour véhicule électrique',
      metaLabel: 'Recharge solaire dédiée',
      buttonLabel: 'Bientôt disponible',
      svgIcon: AppVectorIcons.colorEvCharger,
      accentColor: Color(0xFF0F766E),
      tintBackground: Color(0xFFCCFBF1),
      iconGradient: [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
      enabled: false,
    ),
  ];

  Offset _tiltOffset = Offset.zero;
  Color? _focusColor;

  void _openProject(BuildContext context, _QuoteProject project) {
    if (!project.enabled || project.projectType == null) {
      AppFeedback.info(
        context,
        'Ce module sera disponible très prochainement.',
      );
      return;
    }

    context.push(
      '/quote/form/${Uri.encodeComponent(project.projectType!)}',
    );
  }

  void _updateParallax(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final nx = ((localPosition.dx / size.width) - 0.5) * 2.0;
    final ny = ((localPosition.dy / size.height) - 0.5) * 2.0;
    final clamped = Offset(nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0));
    if ((clamped - _tiltOffset).distance > 0.03) {
      setState(() => _tiltOffset = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Étude • Installation • Maintenance',
      ),
      body: LayoutBuilder(
        builder: (context, rootConstraints) {
          final viewportSize = rootConstraints.biggest;
          return MouseRegion(
            onHover: (event) => _updateParallax(event.localPosition, viewportSize),
            onExit: (_) {
              if (_tiltOffset != Offset.zero || _focusColor != null) {
                setState(() {
                  _tiltOffset = Offset.zero;
                  _focusColor = null;
                });
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: SolarSystem3DBackground(
                    tiltOffset: _tiltOffset,
                    focusColor: _focusColor,
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;

                      final isDesktop = width >= 760;
                      final crossAxisCount = isDesktop ? 3 : 2;
                      final rowCount = (_projects.length / crossAxisCount).ceil();
                      final maxContainerWidth = isDesktop ? 1040.0 : width;
                      final horizontalPadding = isDesktop ? 24.0 : 12.0;
                      final gap = isDesktop ? 16.0 : 9.0;
                      final topPadding = isDesktop ? 16.0 : 8.0;
                      final heroHeight = (isDesktop ? 70.0 : 58.0) +
                          (textScale - 1.0).clamp(0.0, 1.0) * 18.0;
                      final heroGap = isDesktop ? 14.0 : 8.0;

                      final double bottomPadding;
                      if (isDesktop) {
                        bottomPadding = 22.0;
                      } else if (height >= 700) {
                        bottomPadding = 24.0;
                      } else {
                        bottomPadding = 12.0;
                      }

                      final effectiveWidth =
                          math.min(width, maxContainerWidth) -
                              (horizontalPadding * 2);
                      final colWidth =
                          (effectiveWidth - (gap * (crossAxisCount - 1))) /
                              crossAxisCount;

                      final totalGaps = gap * (rowCount - 1);
                      final availableForGrid = height -
                          topPadding -
                          heroHeight -
                          heroGap -
                          totalGaps -
                          bottomPadding;

                      final minComfortHeight = (isDesktop ? 185.0 : 140.0) +
                          (textScale - 1.0).clamp(0.0, 1.0) * 86.0;
                      final maxCardHeight = isDesktop ? 250.0 : 210.0;
                      final rawCardHeight = availableForGrid / rowCount;
                      final needsScroll = rawCardHeight < minComfortHeight;
                      final targetCardHeight = rawCardHeight.clamp(
                        minComfortHeight,
                        maxCardHeight,
                      );
                      final childAspectRatio =
                          math.max(0.5, colWidth / targetCardHeight);

                      final isCompact = targetCardHeight < 156.0 ||
                          (textScale > 1.15 && targetCardHeight < 178.0);
                      final isSpacious = targetCardHeight >= 215.0;

                      final grid = GridView.builder(
                        shrinkWrap: needsScroll,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _projects.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final project = _projects[index];
                          return _ProjectExecutiveCard(
                            project: project,
                            isCompact: isCompact,
                            isSpacious: isSpacious,
                            onTap: () => _openProject(context, project),
                            onHoverChanged: (hovered) {
                              if (!project.enabled) return;
                              final next = hovered ? project.accentColor : null;
                              if (_focusColor != next) {
                                setState(() => _focusColor = next);
                              }
                            },
                          );
                        },
                      );

                      final innerColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize:
                            needsScroll ? MainAxisSize.min : MainAxisSize.max,
                        children: [
                          SizedBox(
                            height: heroHeight,
                            child: _QuoteHero(isDesktop: isDesktop),
                          ),
                          SizedBox(height: heroGap),
                          if (needsScroll) grid else Expanded(child: grid),
                        ],
                      );

                      final padded = Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          topPadding,
                          horizontalPadding,
                          needsScroll && !isDesktop ? 82.0 : bottomPadding,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContainerWidth,
                            ),
                            child: innerColumn,
                          ),
                        ),
                      );

                      if (needsScroll) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: padded,
                        );
                      }

                      return padded;
                    },
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bottomMargin = constraints.maxHeight >= 640 &&
                              constraints.maxWidth < 760
                          ? 8.0
                          : 18.0;
                      return AiFloatingOrb(
                        initialBottomMargin: bottomMargin,
                        contextPrompt:
                            'Le client consulte la sélection des projets solaires Heliantha Maroc (Pompage solaire, Autoconsommation photovoltaïque, Système solaire hybride avec batteries). Aide-le à choisir la solution solaire adaptée à ses besoins énergétiques.',
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuoteHero extends StatelessWidget {
  const _QuoteHero({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B2239),
            Color(0xFF13355B),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFF4C33D).withValues(alpha: 0.55),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2239).withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -28,
              right: -20,
              child: IgnorePointer(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF4C33D).withValues(alpha: 0.22),
                        const Color(0xFFF4C33D).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 12,
                vertical: isDesktop ? 10 : 6,
              ),
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 40 : 34,
                    height: isDesktop ? 40 : 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4C33D).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                      border: Border.all(
                        color: const Color(0xFFF4C33D).withValues(alpha: 0.55),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AppSvgIcon(
                      AppVectorIcons.sparkle,
                      color: const Color(0xFFF4C33D),
                      size: isDesktop ? 19 : 17,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 14 : 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quel est votre projet ?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? 18.0 : 15.0,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 1.5),
                        Text(
                          'Choisissez votre solution solaire.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w500,
                            fontSize: isDesktop ? 12.5 : 11.0,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 180 : 108,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 12 : 9,
                          vertical: isDesktop ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4C33D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isDesktop
                              ? 'Gratuit · 2 min · PDF'
                              : 'Offert · 2 min',
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color(0xFF0B2239),
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? 11.5 : 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectExecutiveCard extends StatefulWidget {
  const _ProjectExecutiveCard({
    required this.project,
    required this.onTap,
    required this.onHoverChanged,
    this.isCompact = false,
    this.isSpacious = false,
  });

  final _QuoteProject project;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;
  final bool isCompact;
  final bool isSpacious;

  @override
  State<_ProjectExecutiveCard> createState() => _ProjectExecutiveCardState();
}

class _ProjectExecutiveCardState extends State<_ProjectExecutiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isCompact = widget.isCompact;
    final isSpacious = widget.isSpacious;
    final active = _hovered || _pressed;
    final borderRadius = BorderRadius.circular(isCompact ? 16 : 18);

    final accent = project.accentColor;
    final tintBg = project.tintBackground;
    final borderColor = project.enabled
        ? (project.featured
            ? const Color(0xFFE5A93C).withValues(alpha: active ? 1.0 : 0.88)
            : accent.withValues(alpha: active ? 0.68 : 0.36))
        : const Color(0xFFCBD5E1).withValues(alpha: active ? 0.98 : 0.85);

    final bgColors = project.enabled
        ? [
            Colors.white.withValues(alpha: active ? 0.94 : 0.82),
            const Color(0xFFF8FBFF).withValues(alpha: active ? 0.97 : 0.87),
          ]
        : [
            const Color(0xFFF8FAFC).withValues(alpha: active ? 0.85 : 0.76),
            const Color(0xFFF1F5F9).withValues(alpha: active ? 0.90 : 0.82),
          ];

    return Semantics(
      button: true,
      label: '${project.title} - ${project.buttonLabel}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          widget.onHoverChanged(true);
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
          widget.onHoverChanged(false);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered && project.enabled ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgColors,
              ),
              border: Border.all(
                color: borderColor,
                width: active ? 1.50 : 1.20,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2239).withValues(
                    alpha: project.enabled
                        ? (active ? 0.16 : 0.10)
                        : (active ? 0.08 : 0.04),
                  ),
                  blurRadius: project.enabled ? (active ? 22 : 18) : 10,
                  offset: Offset(
                    0,
                    project.enabled ? (active ? 9 : 7) : 4,
                  ),
                ),
                if (project.featured)
                  BoxShadow(
                    color: const Color(0xFFF4C33D).withValues(
                      alpha: active ? 0.28 : 0.18,
                    ),
                    blurRadius: active ? 20 : 16,
                    offset: const Offset(0, 3),
                  )
                else if (project.enabled && active)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  // Reflet spéculaire léger sans BackdropFilter (60 FPS garantis)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0x28FFFFFF),
                              Color(0x06FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [0.0, 0.35, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: borderRadius,
                      onTap: widget.onTap,
                      onHighlightChanged: (value) =>
                          setState(() => _pressed = value),
                      splashColor: accent.withValues(alpha: 0.10),
                      highlightColor: accent.withValues(alpha: 0.05),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              isSpacious ? 16.0 : (isCompact ? 9.0 : 11.5),
                          vertical:
                              isSpacious ? 15.0 : (isCompact ? 8.0 : 10.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Médaillon SVG + Tag domaine
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width:
                                      isSpacious ? 46 : (isCompact ? 34 : 38),
                                  height:
                                      isSpacious ? 46 : (isCompact ? 34 : 38),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: project.iconGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      isSpacious ? 13 : (isCompact ? 10 : 12),
                                    ),
                                    border: Border.all(
                                      color: accent.withValues(
                                        alpha: project.enabled ? 0.36 : 0.28,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.14),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: AppSvgIcon(
                                    project.svgIcon,
                                    size: isSpacious
                                        ? 25
                                        : (isCompact ? 19.0 : 21.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSpacious ? 9 : 7,
                                      vertical: isSpacious ? 3.5 : 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tintBg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: accent.withValues(
                                          alpha: project.enabled ? 0.34 : 0.24,
                                        ),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        project.tag,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: isSpacious
                                              ? 10.5
                                              : (isCompact ? 8.8 : 9.5),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 2. Titre + description centrés verticalement
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    project.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: project.enabled
                                          ? const Color(0xFF0B2239)
                                          : const Color(0xFF334155),
                                      fontWeight: FontWeight.w900,
                                      fontSize: isSpacious
                                          ? 16.5
                                          : (isCompact ? 13.0 : 14.0),
                                      letterSpacing: -0.2,
                                      height: 1.15,
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 2 : 4),
                                  Text(
                                    project.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: project.enabled
                                          ? const Color(0xFF475569)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                      fontSize: isSpacious
                                          ? 12.5
                                          : (isCompact ? 10.2 : 11.0),
                                      height: 1.24,
                                    ),
                                  ),
                                  if (isSpacious) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          project.enabled
                                              ? Icons.check_circle_rounded
                                              : Icons.schedule_rounded,
                                          size: 13.5,
                                          color: project.enabled
                                              ? accent
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            project.metaLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: project.enabled
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // 3. Bouton CTA plein haute visibilité aligné sur les 6 cartes
                            if (project.enabled)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: double.infinity,
                                height: isSpacious
                                    ? 38.0
                                    : (isCompact ? 29.0 : 33.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  gradient: LinearGradient(
                                    colors: project.featured
                                        ? (active
                                            ? const [
                                                Color(0xFFFDE047),
                                                Color(0xFFF4C33D),
                                              ]
                                            : const [
                                                Color(0xFFF4C33D),
                                                Color(0xFFE5A93C),
                                              ])
                                        : (active
                                            ? const [
                                                Color(0xFF0E2C4A),
                                                Color(0xFF183D73),
                                              ]
                                            : const [
                                                Color(0xFF0B2239),
                                                Color(0xFF132F5B),
                                              ]),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (project.featured
                                              ? const Color(0xFFE5A93C)
                                              : const Color(0xFF0B2239))
                                          .withValues(
                                        alpha: active ? 0.34 : 0.22,
                                      ),
                                      blurRadius: active ? 11 : 8,
                                      offset: Offset(0, active ? 4 : 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        project.buttonLabel,
                                        style: TextStyle(
                                          color: project.featured
                                              ? const Color(0xFF0B2239)
                                              : Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: isSpacious
                                              ? 12.4
                                              : (isCompact ? 10.4 : 11.2),
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      AppSvgIcon(
                                        AppVectorIcons.arrowForward,
                                        color: project.featured
                                            ? const Color(0xFF0B2239)
                                            : const Color(0xFFF4C33D),
                                        size: isSpacious ? 12.5 : 11.5,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                height: isSpacious
                                    ? 38.0
                                    : (isCompact ? 29.0 : 33.0),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFD8E1EC)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        color: const Color(0xFF475569),
                                        size: isSpacious ? 13.5 : 12.0,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        project.buttonLabel,
                                        style: TextStyle(
                                          color: const Color(0xFF475569),
                                          fontWeight: FontWeight.w700,
                                          fontSize: isSpacious
                                              ? 12.0
                                              : (isCompact ? 10.0 : 10.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
}

class _QuoteProject {
  const _QuoteProject({
    required this.title,
    required this.tag,
    required this.description,
    required this.metaLabel,
    required this.buttonLabel,
    required this.svgIcon,
    required this.accentColor,
    required this.tintBackground,
    required this.iconGradient,
    required this.enabled,
    this.projectType,
    this.featured = false,
  });

  final String title;
  final String tag;
  final String description;
  final String metaLabel;
  final String buttonLabel;
  final String svgIcon;
  final Color accentColor;
  final Color tintBackground;
  final List<Color> iconGradient;
  final bool enabled;
  final String? projectType;
  final bool featured;
}
