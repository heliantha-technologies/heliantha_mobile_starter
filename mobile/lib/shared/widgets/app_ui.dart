import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.3,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          _SectionActionButton(
            label: actionLabel!,
            onTap: onAction!,
          ),
        ],
      ],
    );
  }
}

class _SectionActionButton extends StatefulWidget {
  const _SectionActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_SectionActionButton> createState() => _SectionActionButtonState();
}

class _SectionActionButtonState extends State<_SectionActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;
    final borderRadius = BorderRadius.circular(AppRadii.md);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.97 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            splashColor: AppColors.sun.withValues(alpha: 0.18),
            highlightColor: AppColors.sun.withValues(alpha: 0.10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 34, minWidth: 88),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.sun : AppColors.surface,
                borderRadius: borderRadius,
                border: Border.all(
                  color: active ? AppColors.sun : AppColors.premiumLine,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(
                      alpha: active ? 0.12 : 0.06,
                    ),
                    blurRadius: active ? 14 : 9,
                    offset: Offset(0, active ? 7 : 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.navy.withValues(alpha: 0.92),
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

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.backgroundColor = AppColors.softBlue,
    this.foregroundColor = AppColors.blue,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppStatusPanel extends StatelessWidget {
  const AppStatusPanel({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: _surfaceGradient(AppColors.surface),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.premiumLine),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: AppColors.blue, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class ResponsivePagePadding extends StatelessWidget {
  const ResponsivePagePadding({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.top = 16,
    this.bottom = 24,
  });

  final Widget child;
  final double maxWidth;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720 ? 24.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppSurface extends StatefulWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.premiumLine,
    this.radius = AppRadii.lg,
    this.onTap,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  State<AppSurface> createState() => _AppSurfaceState();
}

class _AppSurfaceState extends State<AppSurface> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final borderRadius = BorderRadius.circular(widget.radius);
    final decoration = BoxDecoration(
      color: widget.backgroundColor,
      gradient: _surfaceGradient(widget.backgroundColor),
      borderRadius: borderRadius,
      border: Border.all(
        color: interactive && _hovered ? AppColors.blue : widget.borderColor,
      ),
      boxShadow: widget.shadow || (interactive && _hovered)
          ? [
              BoxShadow(
                color: AppColors.navy.withValues(
                  alpha: interactive && _hovered ? 0.10 : 0.07,
                ),
                blurRadius: interactive && _hovered ? 22 : 18,
                offset: Offset(0, interactive && _hovered ? 10 : 9),
              ),
            ]
          : null,
    );

    if (!interactive) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: widget.padding,
        decoration: decoration,
        child: widget.child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.98 : (_hovered ? 1.006 : 1),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            splashColor: AppColors.blue.withValues(alpha: 0.07),
            highlightColor: AppColors.blue.withValues(alpha: 0.035),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              decoration: decoration,
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.blue,
    this.backgroundColor = AppColors.softBlue,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = color == AppColors.sun ? AppColors.navy : color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: _surfaceGradient(backgroundColor),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.blue;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        onTap: onTap,
        leading: AppIconBadge(
          icon: icon,
          color: color,
          backgroundColor: danger ? const Color(0xFFFFEFEF) : AppColors.softBlue,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: danger ? AppColors.danger : AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: danger ? AppColors.danger : AppColors.muted,
        ),
      ),
    );
  }
}

LinearGradient? _surfaceGradient(Color color) {
  if (color != AppColors.surface) {
    return null;
  }

  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.surface,
      AppColors.surfaceGlow,
      Color(0xFFF8FBFD),
    ],
  );
}
