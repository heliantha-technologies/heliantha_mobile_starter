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

  /// Site sans réseau (Off-Grid) : maison autonome avec énergie intégrée
  static const String offGridHome = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 10.5L12 3l9 7.5"/>
  <path d="M5.5 8.8V20a1.5 1.5 0 0 0 1.5 1.5h10a1.5 1.5 0 0 0 1.5-1.5V8.8"/>
  <path d="M12.8 10.5L10 14.5h4l-2.8 4"/>
</svg>
''';

  /// Chauffage solaire : rayonnement solaire et ondes d'eau chaude
  static const String solarThermal = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="8.5" r="3.2"/>
  <line x1="12" y1="2.5" x2="12" y2="3.8"/>
  <line x1="6.8" y1="4.5" x2="7.8" y2="5.5"/>
  <line x1="17.2" y1="4.5" x2="16.2" y2="5.5"/>
  <line x1="5" y1="9.5" x2="6.3" y2="9.5"/>
  <line x1="19" y1="9.5" x2="17.7" y2="9.5"/>
  <path d="M4.5 15.5c1.7-1.3 3.3-1.3 5 0s3.3 1.3 5 0 3.3-1.3 5 0"/>
  <path d="M4.5 19.5c1.7-1.3 3.3-1.3 5 0s3.3 1.3 5 0 3.3-1.3 5 0"/>
</svg>
''';

  /// Recharge électrique : borne de recharge solaire avec prise et éclair
  static const String evCharger = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
  <rect x="4" y="3" width="11" height="18" rx="2.5"/>
  <path d="M15 9h1.8a1.7 1.7 0 0 1 1.7 1.7v6.3a1.5 1.5 0 0 0 3 0V8.5L19 6"/>
  <path d="M10.5 7.5l-2.5 4h3.5l-2.5 4"/>
</svg>
''';

  // ==========================================
  // ICÔNES MULTICOLORES DEVIS B2B (DUOTONE / VIVES)
  // ==========================================

  /// Pompage solaire multicolore : goutte cyan/azur glossy et onde marine
  static const String colorPump = '''
<svg viewBox="0 0 24 24" fill="none">
  <path d="M12 2.4l5.8 5.9a8.2 8.2 0 1 1-11.6 0L12 2.4z" fill="#38BDF8" stroke="#0369A1" stroke-width="1.75" stroke-linejoin="round"/>
  <path d="M6.2 14.4c1.7 0.9 3.6 0.9 5.8 0s4.1-0.9 5.8 0a6.6 6.6 0 0 1-11.6 0z" fill="#0284C7"/>
  <path d="M8.4 13.8c1.2-0.8 2.4-0.8 3.6 0s2.4 0.8 3.6 0" stroke="#E0F2FE" stroke-width="1.65" stroke-linecap="round"/>
  <circle cx="9.6" cy="9.2" r="1.15" fill="#E0F2FE"/>
</svg>
''';

  /// Site sans réseau (Off-Grid) multicolore : maison indigo + toit solaire et éclair or
  static const String colorOffGridHome = '''
<svg viewBox="0 0 24 24" fill="none">
  <path d="M5.5 10.2V19.6a1.6 1.6 0 0 0 1.6 1.6h9.8a1.6 1.6 0 0 0 1.6-1.6v-9.4L12 4.8l-6.5 5.4z" fill="#E0E7FF" stroke="#4338CA" stroke-width="1.65" stroke-linejoin="round"/>
  <path d="M2.6 10.7L12 3l9.4 7.7" stroke="#3730A3" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M13.2 10.2L9.4 15.1h3.2l-1.8 4.1 4.2-5.1h-3.1l1.3-3.9z" fill="#F59E0B" stroke="#B45309" stroke-width="0.9" stroke-linejoin="round"/>
</svg>
''';

  /// Panneau photovoltaïque multicolore : cellules bleu saphir + soleil doré
  static const String colorSolarPanel = '''
<svg viewBox="0 0 24 24" fill="none">
  <circle cx="18.2" cy="5.6" r="3.1" fill="#FBBF24" stroke="#D97706" stroke-width="1.35"/>
  <rect x="2.6" y="7" width="16.4" height="11.6" rx="2.3" fill="#0284C7" stroke="#0B2239" stroke-width="1.7"/>
  <line x1="2.8" y1="12.8" x2="18.8" y2="12.8" stroke="#BAE6FD" stroke-width="1.3"/>
  <line x1="8.1" y1="7.2" x2="8.1" y2="18.4" stroke="#BAE6FD" stroke-width="1.3"/>
  <line x1="13.5" y1="7.2" x2="13.5" y2="18.4" stroke="#BAE6FD" stroke-width="1.3"/>
  <path d="M6.2 21.3h9.2" stroke="#0B2239" stroke-width="1.9" stroke-linecap="round"/>
  <path d="M10.8 18.6v2.7" stroke="#0B2239" stroke-width="1.9" stroke-linecap="round"/>
</svg>
''';

  /// Solaire avec batteries multicolore : bloc émeraude + éclair or
  static const String colorBattery = '''
<svg viewBox="0 0 24 24" fill="none">
  <rect x="2.4" y="6.2" width="16.8" height="11.6" rx="2.8" fill="#10B981" stroke="#065F46" stroke-width="1.7"/>
  <path d="M21.4 9.8v4.4" stroke="#065F46" stroke-width="2.3" stroke-linecap="round"/>
  <rect x="4.8" y="8.5" width="3.2" height="7" rx="0.9" fill="#D1FAE5"/>
  <path d="M12.2 8.4L9.2 12.6h2.5l-1.2 3.2 3.5-4.3h-2.5l0.7-3.1z" fill="#FDE047" stroke="#B45309" stroke-width="0.9" stroke-linejoin="round"/>
</svg>
''';

  /// Chauffage solaire (Thermique) multicolore : soleil corail/or + ondes d'eau
  static const String colorSolarThermal = '''
<svg viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="8.4" r="3.4" fill="#FBBF24" stroke="#EA580C" stroke-width="1.65"/>
  <line x1="12" y1="2.2" x2="12" y2="3.7" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="6.7" y1="4.2" x2="7.8" y2="5.3" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="17.3" y1="4.2" x2="16.2" y2="5.3" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="4.6" y1="9.1" x2="6.1" y2="9.1" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="17.9" y1="9.1" x2="19.4" y2="9.1" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M4.2 15.6c1.8-1.4 3.5-1.4 5.2 0s3.4 1.4 5.2 0 3.4-1.4 5.2 0" stroke="#EA580C" stroke-width="2.0" stroke-linecap="round"/>
  <path d="M4.2 19.8c1.8-1.4 3.5-1.4 5.2 0s3.4 1.4 5.2 0 3.4-1.4 5.2 0" stroke="#0284C7" stroke-width="2.0" stroke-linecap="round"/>
</svg>
''';

  /// Recharge électrique (Borne VE) multicolore : borne teal + éclair or + câble
  static const String colorEvCharger = '''
<svg viewBox="0 0 24 24" fill="none">
  <rect x="3.8" y="3.2" width="11.2" height="17.6" rx="2.6" fill="#14B8A6" stroke="#115E59" stroke-width="1.7"/>
  <rect x="5.8" y="5.4" width="7.2" height="4.2" rx="1.1" fill="#CCFBF1"/>
  <path d="M15 9.2h1.8a1.7 1.7 0 0 1 1.7 1.7v5.9a1.5 1.5 0 0 0 3 0V8.4L19 5.8" stroke="#0F766E" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="19" cy="5.8" r="1.2" fill="#0284C7"/>
  <path d="M10.4 11.4l-2.4 3.6h2.6l-1.4 3.3 3.4-4.2H10l0.4-2.7z" fill="#FDE047" stroke="#B45309" stroke-width="0.9" stroke-linejoin="round"/>
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

  /// Logo vectoriel WhatsApp épuré
  static const String whatsapp = '''
<svg viewBox="0 0 24 24" fill="currentColor" fill-rule="evenodd" clip-rule="evenodd">
  <path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91C21.95 6.45 17.5 2 12.04 2zm5.82 14.12c-.24.68-1.42 1.3-1.97 1.38-.51.07-1.15.1-1.85-.12-.43-.14-.98-.32-1.69-.63-2.97-1.28-4.91-4.27-5.06-4.47-.15-.2-1.21-1.61-1.21-3.07s.77-2.18 1.04-2.48c.27-.3.6-.37.8-.37h.58c.19 0 .44-.07.69.52.26.62.88 2.14.96 2.3.08.16.13.34.03.54-.1.2-.15.32-.3.5-.15.17-.31.38-.44.51-.15.15-.3.31-.13.61.17.3.77 1.27 1.65 2.05 1.13 1.01 2.09 1.32 2.39 1.47.3.15.48.13.66-.07.18-.2.75-.87.95-1.17.2-.3.4-.25.67-.15.27.1 1.74.82 2.04.97.3.15.5.22.57.34.07.12.07.7-.17 1.38z"/>
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

