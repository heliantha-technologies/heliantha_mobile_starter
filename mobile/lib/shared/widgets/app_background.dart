import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const helianthaBackgroundAsset = 'assets/brand/fond_arriere_plan.png';
const helianthaSolarIosBackgroundAsset = 'assets/brand/solar_ios_bg.jpg';

class HelianthaBackground extends StatelessWidget {
  const HelianthaBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppColors.background),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Image.asset(
              helianthaBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.background.withValues(alpha: 0.92),
                    AppColors.surfaceGlow.withValues(alpha: 0.88),
                    AppColors.softBlue.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
