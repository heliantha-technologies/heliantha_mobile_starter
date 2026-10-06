import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
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

class AssistantProductCard extends StatelessWidget {
  const AssistantProductCard({super.key, required this.product});

  final AssistantProduct product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => AssistantProductDetailsSheet.show(context, product),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: Color(0xFF64748B)),
                ],
              ),
              if (product.reference != null) ...[
                const SizedBox(height: 5),
                Text('Réf. ${product.reference}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
              if (product.description != null) ...[
                const SizedBox(height: 4),
                Text(product.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF475569))),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_priceLabel(product),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  Text(_stockLabel(product),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: product.inStock == true
                            ? const Color(0xFF047857)
                            : const Color(0xFF64748B),
                      )),
                ],
              ),
              const SizedBox(height: 5),
              const Text('Voir la fiche produit',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uses the returned catalogue facts directly, without crossing catalogue IDs.
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
      // The same helpful fallback covers absent apps and platform errors.
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
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Fiche produit',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Fermer la fiche produit',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(product.name,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              if (product.reference != null) ...[
                const SizedBox(height: 8),
                SelectableText('Référence : ${product.reference}'),
              ],
              if (product.description != null) ...[
                const SizedBox(height: 16),
                const Text('Caractéristiques',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                SelectableText(product.description!),
              ],
              const SizedBox(height: 18),
              Text(_priceLabel(product),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_stockLabel(product)),
              const SizedBox(height: 8),
              const Text(
                  'Prix et disponibilité transmis par le catalogue au moment de la réponse.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              if (product.datasheetUri != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openLink(context, product.datasheetUri!),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Fiche technique'),
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
                      backgroundColor: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
