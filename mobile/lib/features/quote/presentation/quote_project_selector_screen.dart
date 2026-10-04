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

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    vertical,
                    horizontal,
                    0,
                  ),
                  child: Column(
                    children: [
                      _QuoteHero(height: heroHeight, dense: shortHeight),
                      SizedBox(height: gap),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 76),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _projects.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                constraints.maxWidth >= 720 ? 3 : 2,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            childAspectRatio:
                                constraints.maxWidth >= 720 ? 0.90 : 0.76,
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

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2537).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge icône squircle pastel avec l'émoji exact
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FA),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      project.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Titre
                  Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF162D42),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.0,
                      height: 1.15,
                    ),
                  ),

                  // Tag éventuel (ex: Off-Grid, Photovoltaïque, Hybride)
                  if (project.tag != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      project.tag!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2B4D66),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.0,
                      ),
                    ),
                  ],

                  // Sous-titre / description
                  const SizedBox(height: 3),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5A7184),
                      fontWeight: FontWeight.w500,
                      fontSize: 11.0,
                      height: 1.25,
                    ),
                  ),

                  // Spacer pour ancrer le bouton tout en bas de la carte sans jamais recouvrir le texte
                  const Spacer(),

                  // Bouton d'action capsule en Bleu Pétrole Nuit
                  Container(
                    width: double.infinity,
                    height: 34,
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
                              fontSize: 11.5,
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

