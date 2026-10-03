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
      description: 'Forage, irrigation, eau.',
      buttonLabel: 'Estimer mon pompage',
      emoji: '💧',
      projectType: 'pompage',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Site sans réseau',
      tag: 'Off-Grid',
      description: 'Produisez et stockez votre énergie.',
      buttonLabel: 'Bientot disponible',
      emoji: '🏠',
      enabled: false,
    ),
    _QuoteProject(
      title: 'Réduire ma consommation',
      tag: 'Photovoltaïque',
      description: 'Réduisez votre facture avec le solaire.',
      buttonLabel: 'Estimer mes économies',
      emoji: '☀️',
      projectType: 'autoconsommation',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Solaire avec batteries',
      tag: 'Hybride',
      description: 'Solaire et stockage, en continuité.',
      buttonLabel: 'Estimer mon installation',
      emoji: '🔋',
      projectType: 'hybride',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Chauffage solaire',
      description: 'Eau chaude solaire.',
      buttonLabel: 'Bientot disponible',
      emoji: '♨️',
      enabled: false,
    ),
    _QuoteProject(
      title: 'Recharge électrique',
      description: 'Une borne adaptée à votre véhicule.',
      buttonLabel: 'Bientot disponible',
      emoji: '🚗',
      enabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Étude • Installation • Maintenance',
      ),
      body: Stack(
        children: [
          // Fond d'écran avec panneaux solaires & ciel subtil
          Positioned.fill(
            child: Image.asset(
              helianthaBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFD6E8F6).withValues(alpha: 0.88),
                    const Color(0xFFE8F2FA).withValues(alpha: 0.90),
                    const Color(0xFFF1F6FB).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          // Grille des cartes
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortHeight = constraints.maxHeight < 620;
                final veryShortHeight = constraints.maxHeight < 540;
                final horizontal = constraints.maxWidth >= 720 ? 24.0 : 12.0;
                final vertical = veryShortHeight ? 8.0 : 10.0;
                final gap = veryShortHeight ? 8.0 : 12.0;
                final heroHeight =
                    veryShortHeight ? 56.0 : (shortHeight ? 66.0 : 78.0);
                final gridHeight =
                    constraints.maxHeight - (vertical * 2) - heroHeight - gap;
                final cardHeight =
                    ((gridHeight - (gap * 2)) / 3).clamp(90.0, 195.0);

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    vertical,
                    horizontal,
                    vertical,
                  ),
                  child: Column(
                    children: [
                      _QuoteHero(height: heroHeight, dense: shortHeight),
                      SizedBox(height: gap),
                      Expanded(
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _projects.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            mainAxisExtent: cardHeight,
                          ),
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            return _ProjectCard(
                              project: project,
                              onTap: () => _openProject(context, project),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Orbe IA flottant déplaçable avec clignotement de présence
          const Positioned.fill(
            child: AiFloatingOrb(
              contextPrompt:
                  'Le client consulte la sélection des projets solaires Heliantha Maroc (Pompage solaire, Autoconsommation photovoltaïque, Système solaire hybride avec batteries). Aide-le à choisir la solution solaire adaptée à ses besoins énergétiques.',
            ),
          ),
        ],
      ),
    );
  }

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
}

class _QuoteHero extends StatelessWidget {
  const _QuoteHero({
    required this.height,
    required this.dense,
  });

  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2537).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 14,
          vertical: dense ? 8 : 10,
        ),
        child: Row(
          children: [
            HelianthaLogo(
              size: dense ? 36 : 42,
              padding: 3,
              showShadow: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quel est votre projet ?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF102638),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          fontSize: dense ? 16 : 18,
                        ),
                  ),
                  if (!dense) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Choisissez votre solution solaire.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5A7184),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
  });

  final _QuoteProject project;
  final VoidCallback onTap;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ultra = constraints.maxHeight < 100;
        final tiny = constraints.maxHeight < 130;
        final compact = constraints.maxHeight < 155;
        final padding = ultra ? 6.0 : (tiny ? 8.0 : (compact ? 10.0 : 13.0));
        final iconBoxSize = ultra ? 26.0 : (tiny ? 30.0 : (compact ? 34.0 : 38.0));
        final emojiSize = ultra ? 14.0 : (tiny ? 16.0 : (compact ? 18.0 : 20.0));
        final buttonHeight = tiny ? 30.0 : (compact ? 34.0 : 38.0);
        final hideDescription = constraints.maxHeight < 128;

        return AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2537).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge icône squircle pastel avec l'émoji exact
                      Container(
                        width: iconBoxSize,
                        height: iconBoxSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          project.emoji,
                          style: TextStyle(fontSize: emojiSize),
                        ),
                      ),
                      SizedBox(height: ultra ? 3 : (tiny ? 5 : 8)),
                      // Section Textes (Titre + Tag éventuel + Description)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: ultra
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF162D42),
                                fontWeight: FontWeight.w800,
                                fontSize: tiny ? 13.0 : 15.0,
                                height: 1.15,
                              ),
                            ),
                            if (project.tag != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                project.tag!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF2B4D66),
                                  fontWeight: FontWeight.w700,
                                  fontSize: compact ? 10.5 : 11.5,
                                ),
                              ),
                            ],
                            if (!hideDescription) ...[
                              const SizedBox(height: 2),
                              Text(
                                project.description,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF5A7184),
                                  fontWeight: FontWeight.w500,
                                  fontSize: compact ? 10.5 : 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Bouton d'action capsule en Bleu Pétrole Nuit
                      if (!ultra)
                        Container(
                          width: double.infinity,
                          height: buttonHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF223E56),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  project.buttonLabel,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.8,
                                  ),
                                ),
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
      },
    );
  }
}

class _QuoteProject {
  const _QuoteProject({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.emoji,
    required this.enabled,
    this.tag,
    this.projectType,
  });

  final String title;
  final String? tag;
  final String description;
  final String buttonLabel;
  final String emoji;
  final bool enabled;
  final String? projectType;
}

