import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../assistant/presentation/widgets/ai_floating_orb.dart';

class QuoteProjectSelectorScreen extends StatefulWidget {
  const QuoteProjectSelectorScreen({super.key});

  @override
  State<QuoteProjectSelectorScreen> createState() =>
      _QuoteProjectSelectorScreenState();
}

class _QuoteProjectSelectorScreenState
    extends State<QuoteProjectSelectorScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledDown = false;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled =
        _scrollController.hasClients && _scrollController.offset > 80;
    if (scrolled != _isScrolledDown) {
      setState(() => _isScrolledDown = scrolled);
    }
  }

  void _scrollToBottomOrTop() {
    if (!_scrollController.hasClients) return;
    if (_isScrolledDown) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
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
          // 3. Grille des cartes avec dimensionnement ultra-sécurisé anti-overflow
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isWide = width >= 700;
                final crossAxisCount = isWide ? 3 : 2;
                final horizontalPadding = isWide ? 20.0 : 10.0;
                const gap = 10.0;

                // Calcul de la largeur réelle par colonne
                final containerMaxWidth = isWide ? 960.0 : width;
                final effectiveWidth =
                    math.min(width, containerMaxWidth) - (horizontalPadding * 2);
                final colWidth =
                    (effectiveWidth - (gap * (crossAxisCount - 1))) /
                        crossAxisCount;

                // Hauteur cible des cartes calibrée pour éviter TOUT overflow
                final double targetCardHeight;
                if (isWide) {
                  // Sur grand écran / PC / Tablette : les 2 lignes tiennent sur l'écran
                  final availableH = height - 60.0 - 24.0 - 80.0;
                  final idealH = (availableH - gap) / 2;
                  targetCardHeight = idealH.clamp(165.0, 185.0);
                } else {
                  // Sur mobile : 172 px garantit 0 overflow et un contenu harmonieux
                  targetCardHeight = 172.0;
                }

                final childAspectRatio = colWidth / targetCardHeight;

                Widget content = CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          10.0,
                          horizontalPadding,
                          8.0,
                        ),
                        child: const _QuoteHero(),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        isWide ? 24.0 : 90.0,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
                          childAspectRatio: childAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final project = _projects[index];
                            return _ProjectCard(
                              project: project,
                              onTap: () => _openProject(context, project),
                            );
                          },
                          childCount: _projects.length,
                        ),
                      ),
                    ),
                  ],
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
          // 4. Bouton rond flottant de défilement rapide style iOS (sur mobile uniquement)
          Positioned(
            left: 18,
            bottom: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = MediaQuery.of(context).size.width >= 700;
                if (isWide) return const SizedBox.shrink();

                return GestureDetector(
                  onTap: _scrollToBottomOrTop,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isScrolledDown
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: const Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
          // 5. Orbe IA flottant déplaçable avec clignotement de présence
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
  const _QuoteHero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const HelianthaLogo(
                size: 38,
                padding: 2,
                showShadow: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quel est votre projet ?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 16.0,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choisissez votre solution solaire.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
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
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: project.enabled
                  ? Colors.white.withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
                if (project.enabled)
                  BoxShadow(
                    color: project.accentColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 10.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Ligne supérieure : Icône compacte 40x40 + Tag flexible anti-overflow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: project.accentBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    project.accentColor.withValues(alpha: 0.30),
                                width: 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              project.emoji,
                              style: const TextStyle(fontSize: 21),
                            ),
                          ),
                          if (project.tag != null)
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      project.accentBg.withValues(alpha: 0.95),
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
                                      fontSize: 10.0,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // 2. Section Titre
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 14.0,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // 3. Section Description (Expanded absorbe l'espace élastique sans JAMAIS déborder)
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            project.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF475569)
                                  .withValues(alpha: project.enabled ? 1.0 : 0.85),
                              fontWeight: FontWeight.w500,
                              fontSize: 11.0,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 4. Bouton d'action calibré 36 px (anti-overflow garanti)
                      if (project.enabled)
                        Container(
                          width: double.infinity,
                          height: 36.0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.20),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  project.buttonLabel.replaceAll(' →', ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          height: 36.0,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE2E8F0).withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Color(0xFF64748B),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  project.buttonLabel.replaceAll('⏳ ', ''),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.0,
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
