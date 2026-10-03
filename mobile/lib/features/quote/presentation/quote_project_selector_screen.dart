import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';

class QuoteProjectSelectorScreen extends StatelessWidget {
  const QuoteProjectSelectorScreen({super.key});

  static const _projects = [
    _QuoteProject(
      title: 'Pompage solaire',
      description: 'Forage, irrigation, eau.',
      buttonLabel: 'Estimer mon pompage',
      icon: Icons.water_drop_outlined,
      accent: AppColors.blue,
      soft: AppColors.softBlue,
      projectType: 'pompage',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Site sans réseau',
      tag: 'Off-Grid',
      description: 'Produisez et stockez votre énergie.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.cottage_outlined,
      accent: AppColors.sky,
      soft: Color(0xFFE7F8FB),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Réduire ma consommation',
      tag: 'Photovoltaïque',
      description: 'Réduisez votre facture avec le solaire.',
      buttonLabel: 'Estimer mes économies',
      icon: Icons.wb_sunny_outlined,
      accent: AppColors.sun,
      soft: AppColors.softSun,
      projectType: 'autoconsommation',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Solaire avec batteries',
      tag: 'Hybride',
      description: 'Solaire et stockage, en continuité.',
      buttonLabel: 'Estimer mon installation',
      icon: Icons.battery_charging_full_rounded,
      accent: AppColors.leaf,
      soft: AppColors.softLeaf,
      projectType: 'hybride',
      enabled: true,
    ),
    _QuoteProject(
      title: 'Chauffage solaire',
      description: 'Eau chaude solaire.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.local_fire_department_outlined,
      accent: AppColors.danger,
      soft: Color(0xFFFFEFEF),
      enabled: false,
    ),
    _QuoteProject(
      title: 'Recharge électrique',
      description: 'Une borne adaptée à votre véhicule.',
      buttonLabel: 'Bientôt disponible',
      icon: Icons.ev_station_outlined,
      accent: AppColors.navy,
      soft: AppColors.surfaceMuted,
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final shortHeight = constraints.maxHeight < 620;
          final veryShortHeight = constraints.maxHeight < 540;
          final horizontal = constraints.maxWidth >= 720 ? 24.0 : 12.0;
          final vertical = veryShortHeight ? 8.0 : 10.0;
          final gap = veryShortHeight ? 8.0 : 10.0;
          final heroHeight =
              veryShortHeight ? 54.0 : (shortHeight ? 68.0 : 84.0);
          final gridHeight =
              constraints.maxHeight - (vertical * 2) - heroHeight - gap;
          final cardHeight = ((gridHeight - (gap * 2)) / 3).clamp(76.0, 178.0);

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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE7F8FB).withValues(alpha: 0.90),
                      AppColors.surfaceGlow.withValues(alpha: 0.88),
                      AppColors.softSun.withValues(alpha: 0.74),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: dense ? 8 : 10,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.premiumLine),
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: [
                  HelianthaLogo(
                    size: dense ? 36 : 42,
                    padding: 3,
                    showShadow: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quel est votre projet ?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                        ),
                        if (!dense) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Choisissez une solution solaire.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.slate,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ],
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
  });

  final _QuoteProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        project.accent == AppColors.sun ? AppColors.navy : project.accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ultra = constraints.maxHeight < 96;
        final tiny = constraints.maxHeight < 126;
        final compact = constraints.maxHeight < 150;
        final padding = ultra ? 6.0 : (tiny ? 8.0 : (compact ? 9.0 : 11.0));
        final iconBox = ultra ? 24.0 : (tiny ? 30.0 : (compact ? 34.0 : 38.0));
        final iconSize = ultra ? 15.0 : (tiny ? 17.0 : (compact ? 19.0 : 21.0));
        final buttonHeight = tiny ? 28.0 : (compact ? 32.0 : 36.0);
        final radius = compact ? 16.0 : 18.0;
        final hideDescription = constraints.maxHeight < 126;

        return Opacity(
          opacity: project.enabled ? 1 : 0.72,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: AppColors.premiumLine),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.07),
                      blurRadius: compact ? 12 : 16,
                      offset: Offset(0, compact ? 6 : 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: iconBox,
                            height: iconBox,
                            decoration: BoxDecoration(
                              color: project.soft,
                              borderRadius: BorderRadius.circular(
                                tiny ? 10 : 12,
                              ),
                            ),
                            child: Icon(
                              project.icon,
                              color: iconColor,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: ultra
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              maxLines: tiny ? 2 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: (tiny
                                      ? Theme.of(context).textTheme.labelLarge
                                      : Theme.of(context).textTheme.titleSmall)
                                  ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                              ),
                            ),
                            if (!hideDescription) ...[
                              const SizedBox(height: 3),
                              Text(
                                project.description,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                      fontSize: compact ? 10.5 : null,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!ultra)
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: FilledButton(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: project.enabled
                                  ? AppColors.navy
                                  : AppColors.surfaceMuted,
                              foregroundColor: project.enabled
                                  ? Colors.white
                                  : AppColors.muted,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  tiny ? 9 : 11,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(project.buttonLabel),
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
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.softSun,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.premiumLine),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 9 : null,
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
      backgroundColor: AppColors.surface,
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
      leading: AppIconBadge(
        icon: icon,
        size: 38,
        iconSize: 20,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
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
    required this.soft,
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
  final Color soft;
  final bool enabled;
  final String? projectType;
}
