import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/theme/app_vector_icons.dart';
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

/// Vignette photo intelligente avec support URL distante ou fallback réaliste.
class _AssistantProductThumbnail extends StatelessWidget {
  const _AssistantProductThumbnail({
    required this.product,
  });

  final AssistantProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl != null && product.imageUrl!.trim().isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildRealisticFallback(),
      );
    }

    return _buildRealisticFallback();
  }

  Widget _buildRealisticFallback() {
    final lowerName = '${product.name} ${product.reference ?? ''}'.toLowerCase();

    // Détection du type de produit pour une photo / un visuel contextuel
    final isPanel = lowerName.contains('panneau') ||
        lowerName.contains('bifacial') ||
        lowerName.contains('mono') ||
        lowerName.contains('wc') ||
        lowerName.contains('tiger');

    final isInverter = lowerName.contains('onduleur') ||
        lowerName.contains('hybride') ||
        lowerName.contains('inverter') ||
        lowerName.contains('deye') ||
        lowerName.contains('growatt');

    final isBattery = lowerName.contains('batterie') ||
        lowerName.contains('lithium') ||
        lowerName.contains('lifepo4') ||
        lowerName.contains('stockage');

    final isPump = lowerName.contains('pompe') ||
        lowerName.contains('pompage') ||
        lowerName.contains('variateur');

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
