import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../assistant/presentation/widgets/ai_floating_orb.dart';

class QuoteProjectSelectorScreen extends StatelessWidget {
  const QuoteProjectSelectorScreen({super.key});

  static const _projects = [
    _QuoteProject(
      title: 'Pompage solaire',
      description: 'Forage & irrigation continue',
      buttonLabel: 'Estimer mon pompage →',
      emoji: '💧',
      accentColor: Color(0xFF0284C7),
      accentBg: Color(0xFFE0F2FE),
      projectType: 'pompage',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Site sans réseau',
      tag: 'Off-Grid',
      description: 'Autonomie électrique totale',
      buttonLabel: '⏳ Bientôt disponible',
      emoji: '🏠',
      accentColor: Color(0xFF64748B),
      accentBg: Color(0xFFF1F5F9),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Réduire ma facture',
      tag: 'Photovoltaïque',
      description: 'Autoconsommation & économie',
      buttonLabel: 'Estimer mes économies →',
      emoji: '☀️',
      accentColor: Color(0xFFD97706),
      accentBg: Color(0xFFFEF3C7),
      projectType: 'autoconsommation',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Solaire avec batteries',
      tag: 'Hybride',
      description: 'Stockage Lithium 24/7',
      buttonLabel: 'Estimer mon installation →',
      emoji: '🔋',
      accentColor: Color(0xFF16A34A),
      accentBg: Color(0xFFDCFCE7),
      projectType: 'hybride',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Chauffage solaire',
      description: 'Eau chaude sanitaire solaire',
      buttonLabel: '⏳ Bientôt disponible',
      emoji: '♨️',
      accentColor: Color(0xFF64748B),
      accentBg: Color(0xFFF1F5F9),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Recharge électrique',
      description: 'Borne pour véhicule électrique',
      buttonLabel: '⏳ Bientôt disponible',
      emoji: '🚗',
      accentColor: Color(0xFF64748B),
      accentBg: Color(0xFFF1F5F9),
      enabled: false,
    ),
  ];

  static void _openProject(BuildContext context, _QuoteProject project) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Étude • Installation • Maintenance',
      ),
      body: Stack(
        children: [
          // 1. Image d'arrière-plan haute définition : panneaux photovoltaïques purs & ciel bleu
          Positioned.fill(
            child: Image.asset(
              helianthaSolarIosBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // 2. Léger filtre lumineux pour sublimer les reflets de verre givré
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    const Color(0xFFFED7AA).withValues(alpha: 0.12),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // 3. Grille des cartes avec dimensionnement dynamique 100% sans scroll
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isWide = width >= 700;
                final crossAxisCount = isWide ? 3 : 2;
                final rowCount = (_projects.length / crossAxisCount).ceil(); // 2 sur PC/tablette, 3 sur mobile
                final horizontalPadding = isWide ? 20.0 : 10.0;
                final gap = isWide ? 10.0 : 7.0;

                // Calcul de la largeur réelle par colonne
                final containerMaxWidth = isWide ? 960.0 : width;
                final effectiveWidth =
                    math.min(width, containerMaxWidth) - (horizontalPadding * 2);
                final colWidth =
                    (effectiveWidth - (gap * (crossAxisCount - 1))) /
                        crossAxisCount;

                // Hauteur dynamique allouée aux cartes pour tenir EXACTEMENT sur 1 seul écran
                final fixedVertical = isWide ? 76.0 : 66.0;
                final totalGaps = gap * (rowCount - 1);
                final availableForGrid = height - fixedVertical - totalGaps;
                final targetCardHeight =
                    (availableForGrid / rowCount).clamp(118.0, 190.0);
                final childAspectRatio = colWidth / targetCardHeight;

                // Détecte si les cartes doivent être en mode compact
                final isCompact = targetCardHeight < 152.0;

                final content = Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isWide ? 10.0 : 6.0,
                    horizontalPadding,
                    isWide ? 10.0 : 6.0,
                  ),
                  child: Column(
                    children: [
                      const _QuoteHero(),
                      SizedBox(height: isWide ? 10.0 : 6.0),
                      Expanded(
                        child: GridView.builder(
                          physics: height < 400
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _projects.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            return _ProjectCard(
                              project: project,
                              isCompact: isCompact,
                              onTap: () => _openProject(context, project),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: content,
                    ),
                  );
                }

                return content;
              },
            ),
          ),
          // 4. Orbe IA flottant déplaçable avec clignotement de présence
          const Positioned.fill(
            child: AiFloatingOrb(
              initialBottomMargin: 20.0,
              contextPrompt:
                  'Le client consulte la sélection des projets solaires Heliantha Maroc (Pompage solaire, Autoconsommation photovoltaïque, Système solaire hybride avec batteries). Aide-le à choisir la solution solaire adaptée à ses besoins énergétiques.',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteHero extends StatelessWidget {
  const _QuoteHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const HelianthaLogo(
                size: 32,
                padding: 2,
                showShadow: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quel est votre projet ?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Choisissez votre solution solaire.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.0,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.isCompact = false,
  });

  final _QuoteProject project;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isCompact = widget.isCompact;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: project.enabled
                  ? Colors.white.withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (project.enabled)
                  BoxShadow(
                    color: project.accentColor.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8.0 : 10.0,
                    vertical: isCompact ? 6.5 : 9.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Pastille compacte + Tag flexible
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: isCompact ? 32 : 36,
                            height: isCompact ? 32 : 36,
                            decoration: BoxDecoration(
                              color: project.accentBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: project.accentColor
                                    .withValues(alpha: 0.30),
                                width: 0.9,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              project.emoji,
                              style: TextStyle(
                                fontSize: isCompact ? 16.5 : 19.0,
                              ),
                            ),
                          ),
                          if (project.tag != null)
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 6 : 7,
                                  vertical: isCompact ? 2.0 : 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: project.accentBg
                                      .withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: project.accentColor
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    project.tag!,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: project.accentColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: isCompact ? 9.0 : 9.5,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 4 : 5),

                      // 2. Section Titre
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: isCompact ? 12.8 : 13.8,
                          letterSpacing: -0.2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 1),

                      // 3. Section Description
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            project.description,
                            maxLines: isCompact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF475569).withValues(
                                alpha: project.enabled ? 1.0 : 0.85,
                              ),
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? 9.8 : 10.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 3 : 5),

                      // 4. Bouton d'action calibré
                      if (project.enabled)
                        Container(
                          width: double.infinity,
                          height: isCompact ? 28.0 : 32.0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  project.buttonLabel.replaceAll(' →', ''),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: isCompact ? 10.5 : 11.2,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: isCompact ? 11.5 : 12.5,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          height: isCompact ? 28.0 : 32.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0)
                                .withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  color: const Color(0xFF64748B),
                                  size: isCompact ? 11.0 : 12.0,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  project.buttonLabel.replaceAll('⏳ ', ''),
                                  style: TextStyle(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isCompact ? 10.0 : 10.8,
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
          ),
        ),
      ),
    );
  }
}

class _QuoteProject {
  const _QuoteProject({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.emoji,
    required this.accentColor,
    required this.accentBg,
    required this.enabled,
    this.tag,
    this.projectType,
  });

  final String title;
  final String? tag;
  final String description;
  final String buttonLabel;
  final String emoji;
  final Color accentColor;
  final Color accentBg;
  final bool enabled;
  final String? projectType;
}
