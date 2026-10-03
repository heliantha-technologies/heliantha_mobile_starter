import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/brand_widgets.dart';

class QuoteProjectSelectorScreen extends StatelessWidget {
  const QuoteProjectSelectorScreen({super.key});

  static const _projects = [
    _QuoteProject(
      title: 'Pompage solaire',
      description: 'Forage, irrigation, eau.',
      buttonLabel: 'Estimer mon pompage',
      icon: Icons.water_drop_outlined,
      accent: Color(0xFF0284C7),
      projectType: 'pompage',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Site sans réseau',
      tag: 'Off-Grid',
      description: 'Produisez et stockez votre énergie.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.cottage_outlined,
      accent: Color(0xFF0EA5E9),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Réduire ma consommation',
      tag: 'Photovoltaïque',
      description: 'Réduisez votre facture avec le solaire.',
      buttonLabel: 'Estimer mes économies',
      icon: Icons.wb_sunny_outlined,
      accent: Color(0xFFD97706),
      projectType: 'autoconsommation',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Solaire avec batteries',
      tag: 'Hybride',
      description: 'Solaire et stockage, en continuité.',
      buttonLabel: 'Estimer mon installation',
      icon: Icons.battery_charging_full_rounded,
      accent: Color(0xFF059669),
      projectType: 'hybride',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Chauffage solaire',
      description: 'Eau chaude solaire.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.local_fire_department_outlined,
      accent: Color(0xFFDC2626),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Recharge électrique',
      description: 'Une borne adaptée à votre véhicule.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.ev_station_outlined,
      accent: Color(0xFF475569),
      enabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Étude • Installation • Maintenance',
        actions: [_QuoteMenuButton()],
      ),
      body: Stack(
        children: [
          // 1. Fond d'écran avec technicien solaire HeliAntha + canevas satiné iOS
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
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFF8FAFC).withValues(alpha: 0.88),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          // Halos lumineux subtils (Aurora blur)
          Positioned(
            top: -50,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          // 2. Contenu en surfaces de verre dépoli
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortHeight = constraints.maxHeight < 620;
                final veryShortHeight = constraints.maxHeight < 540;
                final horizontal = constraints.maxWidth >= 720 ? 24.0 : 12.0;
                final vertical = veryShortHeight ? 8.0 : 10.0;
                final gap = veryShortHeight ? 8.0 : 11.0;
                final heroHeight =
                    veryShortHeight ? 56.0 : (shortHeight ? 68.0 : 80.0);
                final gridHeight =
                    constraints.maxHeight - (vertical * 2) - heroHeight - gap;
                final cardHeight =
                    ((gridHeight - (gap * 2)) / 3).clamp(78.0, 185.0);

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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : 14,
              vertical: dense ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
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
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              fontSize: dense ? 16 : 18,
                            ),
                      ),
                      if (!dense) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Étude & dimensionnement solaire immédiat.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF475569),
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
        final ultra = constraints.maxHeight < 96;
        final tiny = constraints.maxHeight < 126;
        final compact = constraints.maxHeight < 152;
        final padding = ultra ? 6.0 : (tiny ? 8.0 : (compact ? 9.0 : 12.0));
        final iconBox = ultra ? 26.0 : (tiny ? 32.0 : (compact ? 36.0 : 40.0));
        final iconSize = ultra ? 16.0 : (tiny ? 18.0 : (compact ? 20.0 : 22.0));
        final buttonHeight = tiny ? 30.0 : (compact ? 34.0 : 38.0);
        final hideDescription = constraints.maxHeight < 126;

        return AnimatedScale(
          scale: _pressed && project.enabled ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: widget.onTap,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: project.enabled ? 0.85 : 0.70,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête de la carte : Badge icône & Tag éventuel
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: iconBox,
                                  height: iconBox,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    project.icon,
                                    color: project.accent,
                                    size: iconSize,
                                  ),
                                ),
                                if (project.tag != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: _ProjectTag(
                                        label: project.tag!,
                                        dense: compact,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: ultra ? 3 : (tiny ? 5 : 8)),
                            // Contenu central : Titre en Bleu Nuit intense + descriptif
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
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: tiny ? 13.0 : 15.0,
                                      height: 1.12,
                                    ),
                                  ),
                                  if (!hideDescription) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      project.description,
                                      maxLines: compact ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                        fontSize: compact ? 10.5 : 11.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Bouton d'action capsule squircle
                            if (!ultra)
                              Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: project.enabled
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF0F172A),
                                            Color(0xFF1E293B),
                                          ],
                                        )
                                      : null,
                                  color: project.enabled
                                      ? null
                                      : const Color(0xFFF1F5F9)
                                          .withValues(alpha: 0.9),
                                  boxShadow: project.enabled
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0F172A)
                                                .withValues(alpha: 0.22),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            project.buttonLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: project.enabled
                                                  ? Colors.white
                                                  : const Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w800,
                                              fontSize: compact ? 10.5 : 11.5,
                                            ),
                                          ),
                                        ),
                                        if (project.enabled) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFFF59E0B),
                                            size: 13,
                                          ),
                                        ],
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectTag extends StatelessWidget {
  const _ProjectTag({
    required this.label,
    required this.dense,
  });

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 0.9,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF92400E),
          fontWeight: FontWeight.w900,
          fontSize: dense ? 9.0 : 10.0,
        ),
      ),
    );
  }
}

class _QuoteMenuButton extends StatelessWidget {
  const _QuoteMenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Menu',
      onPressed: () => _showMenu(context),
      icon: const Icon(Icons.menu_rounded),
    );
  }

  static void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuDestination(
                  icon: Icons.home_outlined,
                  label: 'Accueil',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/');
                  },
                ),
                _MenuDestination(
                  icon: Icons.grid_view_rounded,
                  label: 'Catalogue',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/catalog');
                  },
                ),
                _MenuDestination(
                  icon: Icons.favorite_border_rounded,
                  label: 'Favoris',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/favorites');
                  },
                ),
                _MenuDestination(
                  icon: Icons.person_outline_rounded,
                  label: 'Compte',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/account');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuDestination extends StatelessWidget {
  const _MenuDestination({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD97706),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF94A3B8),
      ),
      onTap: onTap,
    );
  }
}

class _QuoteProject {
  const _QuoteProject({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.accent,
    required this.enabled,
    this.tag,
    this.projectType,
  });

  final String title;
  final String? tag;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final String? projectType;
}
