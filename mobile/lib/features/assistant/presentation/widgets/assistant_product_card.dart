import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/theme/app_vector_icons.dart';
import '../../../../shared/utils/api_url.dart';
import '../../../../shared/utils/money.dart';
import '../../data/assistant_reply.dart';

String _priceLabel(AssistantProduct product) => product.price == null
    ? 'Prix à confirmer'
    : '${formatMoney(product.price!, currency: product.currency)} ${product.priceTax}';

String _stockLabel(AssistantProduct product) => switch (product.inStock) {
      true => 'En stock',
      false => 'Indisponible',
      null => 'Disponibilité à confirmer',
    };

/// Carrousel horizontal compact et moderne pour les équipements suggérés par l'IA.
/// Prend très peu de place verticale (~130px) et offre un confort de lecture optimal.
class AssistantProductsCarousel extends StatelessWidget {
  const AssistantProductsCarousel({super.key, required this.products});

  final List<AssistantProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    if (products.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: AssistantProductCard(product: products.first),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 5),
              Text(
                '${products.length} équipements recommandés',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              const Text(
                'Glissez pour comparer ➔',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 268,
                child: AssistantProductCard(
                  product: products[index],
                  inCarousel: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Carte produit élégante, compacte avec photo/visuel réaliste et détails clés.
class AssistantProductCard extends StatelessWidget {
  const AssistantProductCard({
    super.key,
    required this.product,
    this.inCarousel = false,
  });

  final AssistantProduct product;
  final bool inCarousel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => AssistantProductDetailsSheet.show(context, product),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: inCarousel ? 268 : double.infinity,
          height: inCarousel ? 134 : null,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. VIGNETTE PHOTO DU PRODUIT
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: inCarousel ? double.infinity : 108,
                  child: _AssistantProductThumbnail(product: product),
                ),
              ),
              const SizedBox(width: 9),
              // 2. CONTENU TEXTUEL & PRIX
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge stock + Chevron
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.inStock == true
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: product.inStock == true
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _stockLabel(product),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: product.inStock == true
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Nom du produit (2 lignes)
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                    // Réf ou caractéristique courte
                    if (product.reference != null ||
                        product.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.description?.isNotEmpty == true
                            ? product.description!
                            : 'Réf. ${product.reference}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Prix & Lien
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _priceLabel(product),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Voir la fiche produit',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
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

/// Résolution robuste de l'image réelle du produit depuis le catalogue HeliAntha.
String? _resolveEquipmentImage(AssistantProduct product) {
  if (product.imageUrl != null && product.imageUrl!.trim().isNotEmpty) {
    return product.imageUrl!.trim();
  }

  final rawRef = (product.reference ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final rawName = product.name.toUpperCase();
  final rawDesc = (product.description ?? '').toUpperCase();
  final search = '$rawRef $rawName $rawDesc';

  // 1. Onduleurs
  if (search.contains('DEYESUN') ||
      search.contains('SUN18K') ||
      search.contains('SUN10K') ||
      search.contains('SUN6K') ||
      search.contains('18KW') ||
      search.contains('10KW') ||
      search.contains('6KW') ||
      (search.contains('DEYE') && search.contains('ONDULEUR'))) {
    return '/v1/products/331/image?image_id=552'; // Onduleur Hybride Deye 18kW
  }
  if (search.contains('MUST') || search.contains('PV18')) {
    return '/v1/products/340/image?image_id=580'; // Onduleur Must 3.6kW
  }
  if (search.contains('SOLAX') || search.contains('X3') || search.contains('X1')) {
    return '/v1/products/248/image?image_id=351'; // Onduleur SolaX Hybride
  }

  // 2. Panneaux solaires
  if (search.contains('JINKO') || search.contains('725') || search.contains('TIGER')) {
    return '/v1/products/342/image?image_id=583'; // Jinko 725W Tiger Neo
  }
  if (search.contains('CANADIAN') ||
      search.contains('CS6W') ||
      search.contains('CS7N') ||
      search.contains('705') ||
      search.contains('590') ||
      search.contains('585')) {
    return '/v1/products/341/image?image_id=582'; // Canadian Solar 705W / 590W
  }
  if (search.contains('610') || search.contains('JKM610')) {
    return '/v1/products/256/image?image_id=360'; // Jinko 610W Bifacial
  }
  if (search.contains('400') ||
      search.contains('RISEN') ||
      search.contains('ONGRIDPV400') ||
      search.contains('TESTJA400')) {
    return '/v1/products/310/image?image_id=510'; // Panneau Risen / On-Grid 400W
  }
  if (search.contains('715') || search.contains('720')) {
    return '/v1/products/342/image?image_id=583'; // Panneau 715W / 725W
  }

  // 3. Batteries
  if (search.contains('MES') || search.contains('LBM') || search.contains('5220')) {
    return '/v1/products/343/image?image_id=584'; // Batterie MES 5.22kWh
  }
  if (search.contains('BATDEYE5') ||
      search.contains('SEF5') ||
      (search.contains('DEYE') && search.contains('5KWH'))) {
    return '/v1/products/330/image?image_id=545'; // Batterie Deye 5.32kWh
  }
  if (search.contains('BATDEYE15') ||
      search.contains('LP16') ||
      search.contains('15KWH') ||
      (search.contains('MUST') && search.contains('BATTERIE'))) {
    return '/v1/products/270/image?image_id=463'; // Batterie Must / Deye 15kWh
  }
  if (search.contains('DYNESS') || search.contains('POWERBRICK')) {
    return '/v1/products/319/image?image_id=521'; // Batterie Dyness
  }

  // 4. Variateurs & Pompes
  if (search.contains('INOMAX') || search.contains('MAX500') || search.contains('SI23')) {
    return '/v1/products/338/image?image_id=576'; // Variateur Inomax 4kW
  }
  if (search.contains('INVT') || search.contains('GD100') || search.contains('HELINVT')) {
    return '/v1/products/337/image?image_id=573'; // Variateur INVT 2.2kW
  }
  if (search.contains('LEO') ||
      search.contains('4XR') ||
      search.contains('3XR') ||
      search.contains('POMPE') ||
      search.contains('ELECTROPOMPE')) {
    return '/v1/products/301/image?image_id=493'; // Pompe immergée LEO
  }

  // 5. Familles génériques si mention spécifique
  if (search.contains('ONDULEUR') || search.contains('INVERTER') || search.contains('HYBRIDE')) {
    return '/v1/products/331/image?image_id=552';
  }
  if (search.contains('BATTERIE') ||
      search.contains('LITHIUM') ||
      search.contains('LIFEPO4') ||
      search.contains('STOCKAGE')) {
    return '/v1/products/330/image?image_id=545';
  }
  if (search.contains('PANNEAU') || search.contains('PHOTOVOLTAIQUE')) {
    return '/v1/products/342/image?image_id=583';
  }
  if (search.contains('VARIATEUR') || search.contains('VFD')) {
    return '/v1/products/337/image?image_id=573';
  }

  return null;
}

/// Vignette photo intelligente avec support URL distante ou fallback réaliste.
class _AssistantProductThumbnail extends StatelessWidget {
  const _AssistantProductThumbnail({
    required this.product,
  });

  final AssistantProduct product;

  @override
  Widget build(BuildContext context) {
    final rawUrl = _resolveEquipmentImage(product);
    final url = absoluteApiUrl(rawUrl);

    if (url.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          headers: const {'Accept': 'image/*'},
          errorBuilder: (_, __, ___) => _buildRealisticFallback(),
        );
      }
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: const {'Accept': 'image/*'},
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildRealisticFallback(),
      );
    }

    return _buildRealisticFallback();
  }

  Widget _buildRealisticFallback() {
    final lowerName = '${product.name} ${product.reference ?? ''}'.toLowerCase();

    // Détection rigoureuse par type : Onduleurs en premier pour ne pas confondre "monophasé" avec un panneau !
    final isInverter = lowerName.contains('onduleur') ||
        lowerName.contains('inverter') ||
        lowerName.contains('hybride') ||
        lowerName.contains('deye') ||
        lowerName.contains('growatt');

    final isBattery = lowerName.contains('batterie') ||
        lowerName.contains('lithium') ||
        lowerName.contains('lifepo4') ||
        lowerName.contains('stockage');

    final isPump = lowerName.contains('pompe') ||
        lowerName.contains('pompage') ||
        lowerName.contains('variateur');

    final isPanel = lowerName.contains('panneau') ||
        lowerName.contains('photovoltaïque') ||
        lowerName.contains('photovoltaique') ||
        lowerName.contains('bifacial') ||
        lowerName.contains('tiger') ||
        (lowerName.contains('wc') && !isInverter);

    if (isPanel) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/brand/solar_ios_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildVectorFallback(
              gradient: const [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              svgSource: AppVectorIcons.solarPanel,
              iconColor: const Color(0xFFB45309),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SOLAIRE PV',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isInverter) {
      return _buildVectorFallback(
        gradient: const [Color(0xFF1E1B4B), Color(0xFF312E81)],
        svgSource: AppVectorIcons.inverter,
        iconColor: const Color(0xFFA5B4FC),
        label: 'ONDULEUR',
      );
    }

    if (isBattery) {
      return _buildVectorFallback(
        gradient: const [Color(0xFF064E3B), Color(0xFF047857)],
        svgSource: AppVectorIcons.battery,
        iconColor: const Color(0xFFA7F3D0),
        label: 'BATTERIE',
      );
    }

    if (isPump) {
      return _buildVectorFallback(
        gradient: const [Color(0xFF0C4A6E), Color(0xFF0284C7)],
        svgSource: AppVectorIcons.pump,
        iconColor: const Color(0xFFBAE6FD),
        label: 'POMPAGE',
      );
    }

    return _buildVectorFallback(
      gradient: const [Color(0xFF0F172A), Color(0xFF1E293B)],
      svgSource: AppVectorIcons.solarPanel,
      iconColor: const Color(0xFFF59E0B),
      label: 'ÉQUIPEMENT',
    );
  }

  Widget _buildVectorFallback({
    required List<Color> gradient,
    required String svgSource,
    required Color iconColor,
    String? label,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AppSvgIcon(
              svgSource,
              size: 28,
              color: iconColor,
            ),
          ),
          if (label != null)
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fiche détaillée moderne et élégante façon iOS avec visuel grand format.
class AssistantProductDetailsSheet extends StatelessWidget {
  const AssistantProductDetailsSheet({super.key, required this.product});

  final AssistantProduct product;

  static Future<void> show(BuildContext context, AssistantProduct product) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (_) => AssistantProductDetailsSheet(product: product),
      );

  Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Le même fallback sécurise les erreurs de plateforme
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
      content:
          Text('Le lien ne peut pas être ouvert. Contactez un conseiller au '
              '${AppConfig.supportPhoneDisplay}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre supérieure avec titre et bouton fermer
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Fiche produit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer la fiche produit',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // En-tête avec visuel photo et titre
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: _AssistantProductThumbnail(
                        product: product,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.25,
                          ),
                        ),
                        if (product.reference != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              'Référence : ${product.reference}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Caractéristiques techniques
              if (product.description != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Caractéristiques',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  product.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ],

              // Prix et disponibilité
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _priceLabel(product),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: product.inStock == true
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: product.inStock == true
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      _stockLabel(product),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: product.inStock == true
                            ? const Color(0xFF047857)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Prix et disponibilité transmis par le catalogue au moment de la réponse.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // Boutons d'action
              if (product.datasheetUri != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openLink(context, product.datasheetUri!),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Fiche technique'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openLink(
                    context,
                    AppConfig.supportWhatsAppUri(
                      message: 'Bonjour, je souhaite des renseignements sur '
                          '${product.name}'
                          '${product.reference == null ? '' : ' (réf. ${product.reference})'}.',
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Conseiller sur WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
