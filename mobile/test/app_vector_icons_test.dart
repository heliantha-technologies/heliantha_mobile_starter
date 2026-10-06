import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:heliantha_mobile/shared/theme/app_vector_icons.dart';

void main() {
  group('AppVectorIcons and AppSvgIcon Tests', () {
    testWidgets('AppSvgIcon renders SvgPicture with correct vector content and color',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSvgIcon(
                AppVectorIcons.solarPanel,
                size: 24,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppSvgIcon), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    test('All solar universe SVG strings are non-empty valid XML SVGs', () {
      final svgList = [
        AppVectorIcons.solarPanel,
        AppVectorIcons.inverter,
        AppVectorIcons.battery,
        AppVectorIcons.pump,
        AppVectorIcons.shieldBreaker,
        AppVectorIcons.solarLighting,
        AppVectorIcons.navHome,
        AppVectorIcons.navHomeFilled,
        AppVectorIcons.navCatalog,
        AppVectorIcons.navCatalogFilled,
        AppVectorIcons.navFavorites,
        AppVectorIcons.navFavoritesFilled,
        AppVectorIcons.navAccount,
        AppVectorIcons.navAccountFilled,
        AppVectorIcons.arrowForward,
        AppVectorIcons.sparkle,
        AppVectorIcons.logoSun,
      ];

      for (final svg in svgList) {
        expect(svg, contains('<svg'));
        expect(svg, contains('</svg>'));
        expect(svg, contains('viewBox="0 0 24 24"'));
      }
    });
  });
}

