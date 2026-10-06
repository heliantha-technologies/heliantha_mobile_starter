import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bibliothèque d'icônes vectorielles natives SVG (Style iOS / SF Symbols).
/// 
/// Avantages majeurs :
/// 1. Zéro dépendance aux polices de caractères externes ou AssetManifest.
/// 2. Compilées directement en chaînes constantes en mémoire (infaillibles en Web & Mobile).
/// 3. Rendu ultra-net, moderne, courbé style Apple SF Symbols.
class AppVectorIcons {
  const AppVectorIcons._();

  // ==========================================
  // LES 6 UNIVERS SOLAIRES (Style iOS)
  // ==========================================

  /// Panneaux Solaires : module photovoltaïque avec cellules et rayon solaire
  static const String solarPanel = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2.5" y="4" width="19" height="15" rx="3"/>
  <line x1="2.5" y1="11.5" x2="21.5" y2="11.5"/>
  <line x1="8.8" y1="4" x2="8.8" y2="19"/>
  <line x1="15.2" y1="4" x2="15.2" y2="19"/>
  <path d="M5 21.5h14"/>
</svg>
''';

  /// Onduleurs & Hybrides : châssis avec conversion éclair d'énergie
  static const String inverter = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="18" height="18" rx="3.5"/>
  <path d="M13 7.5l-4 5.5h6l-4 5.5"/>
  <circle cx="7" cy="6.5" r="0.75" fill="currentColor"/>
  <circle cx="17" cy="6.5" r="0.75" fill="currentColor"/>
</svg>
''';

  /// Batteries & Stockage : cellule lithium avec niveau de charge
  static const String battery = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2.5" y="6" width="16.5" height="12" rx="3"/>
  <path d="M21.5 10v4" stroke-width="2.2" stroke-linecap="round"/>
  <line x1="6.5" y1="10" x2="6.5" y2="14"/>
  <line x1="10.8" y1="9.5" x2="10.8" y2="14.5"/>
  <line x1="15" y1="10" x2="15" y2="14"/>
</svg>
''';

  /// Pompage & Variateurs : goutte d'eau fluide avec turbine
  static const String pump = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2.8l5.66 5.66a8 8 0 1 1-11.31 0z"/>
  <path d="M8.5 14c1.2-0.9 2.5-0.9 3.5 0s2.3 0.9 3.5 0"/>
</svg>
''';

  /// Coffrets & Câblage : bouclier de protection avec disjoncteur
  static const String shieldBreaker = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 22s8-4 8-10V5.5l-8-3-8 3V12c0 6 8 10 8 10z"/>
  <path d="M9 12h6"/>
  <circle cx="9" cy="12" r="1.2" fill="currentColor"/>
  <line x1="12" y1="8" x2="12" y2="10"/>
  <line x1="12" y1="14" x2="12" y2="16"/>
</svg>
''';

  /// Éclairage Solaire : ampoule rayonnante moderne
  static const String solarLighting = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M9 18h6"/>
  <path d="M10 21h4"/>
  <path d="M12 2a7 7 0 0 0-4 12.7V16h8v-1.3A7 7 0 0 0 12 2z"/>
</svg>
''';

  // ==========================================
  // BARRE DE NAVIGATION INFÉRIEURE (Style iOS)
  // ==========================================

  /// Accueil (Inactif / Outline)
  static const String navHome = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 10.5L12 3l9 7.5V20a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 20v-9.5z"/>
  <path d="M9.5 22.5V13h5v9.5"/>
</svg>
''';

  /// Accueil (Actif / Filled)
  static const String navHomeFilled = '''
<svg viewBox="0 0 24 24" fill="currentColor">
  <path d="M12 2.5L2 10.8h3V20.5a1.5 1.5 0 0 0 1.5 1.5h4.5V14h4v8h4.5a1.5 1.5 0 0 0 1.5-1.5V10.8h3L12 2.5z"/>
</svg>
''';

  /// Catalogue (Inactif / Outline 4-squircle iOS)
  static const String navCatalog = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="7.5" height="7.5" rx="2.5"/>
  <rect x="13.5" y="3" width="7.5" height="7.5" rx="2.5"/>
  <rect x="3" y="13.5" width="7.5" height="7.5" rx="2.5"/>
  <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2.5"/>
</svg>
''';

  /// Catalogue (Actif / Filled)
  static const String navCatalogFilled = '''
<svg viewBox="0 0 24 24" fill="currentColor">
  <rect x="3" y="3" width="7.5" height="7.5" rx="2.5"/>
  <rect x="13.5" y="3" width="7.5" height="7.5" rx="2.5"/>
  <rect x="3" y="13.5" width="7.5" height="7.5" rx="2.5"/>
  <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2.5"/>
</svg>
''';

  /// Favoris (Inactif / Outline)
  static const String navFavorites = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
</svg>
''';

  /// Favoris (Actif / Filled)
  static const String navFavoritesFilled = '''
<svg viewBox="0 0 24 24" fill="currentColor">
  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
</svg>
''';

  /// Compte (Inactif / Outline)
  static const String navAccount = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M20 21v-1.5a4.5 4.5 0 0 0-4.5-4.5h-7A4.5 4.5 0 0 0 4 19.5V21"/>
  <circle cx="12" cy="7" r="4.2"/>
</svg>
''';

  /// Compte (Actif / Filled)
  static const String navAccountFilled = '''
<svg viewBox="0 0 24 24" fill="currentColor">
  <path d="M12 12c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm0 2c-3.33 0-10 1.67-10 5v3h20v-3c0-3.33-6.67-5-10-5z"/>
</svg>
''';

  // ==========================================
  // COMPOSANTS D'ACTION ET SYMBOLES CLÉS
  // ==========================================

  /// Flèche / Chevron d'action iOS
  static const String arrowForward = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
  <path d="M9 18l6-6-6-6"/>
</svg>
''';

  /// Étoile / Brillance dimensionnement IA
  static const String sparkle = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2l2.4 6.6L21 11l-6.6 2.4L12 20l-2.4-6.6L3 11l6.6-2.4L12 2z"/>
</svg>
''';

  /// Soleil rayonnant HeliAntha (Logo fallback)
  static const String logoSun = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="5" fill="currentColor"/>
  <line x1="12" y1="1.5" x2="12" y2="4.5"/>
  <line x1="12" y1="19.5" x2="12" y2="22.5"/>
  <line x1="4.5" y1="4.5" x2="6.6" y2="6.6"/>
  <line x1="17.4" y1="17.4" x2="19.5" y2="19.5"/>
  <line x1="1.5" y1="12" x2="4.5" y2="12"/>
  <line x1="19.5" y1="12" x2="22.5" y2="12"/>
  <line x1="4.5" y1="19.5" x2="6.6" y2="17.4"/>
  <line x1="17.4" y1="6.6" x2="19.5" y2="4.5"/>
</svg>
''';
}

/// Widget affichant un icône vectoriel SVG natif avec gestion de taille et couleur.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.svgSource, {
    super.key,
    this.size = 22,
    this.color,
  });

  final String svgSource;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgSource,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

