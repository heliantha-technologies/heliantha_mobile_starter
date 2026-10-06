/// A catalogue suggestion from the assistant backend. Its ID belongs to the
/// local catalogue and must never be used as a PrestaShop product ID.
class AssistantProduct {
  const AssistantProduct({
    required this.name,
    this.localId,
    this.reference,
    this.description,
    this.price,
    this.currency = 'DH',
    this.priceTax = 'HT',
    this.inStock,
    this.datasheetUri,
  });

  final String name;
  final String? localId;
  final String? reference;
  final String? description;
  final double? price;
  final String currency;
  final String priceTax;
  final bool? inStock;
  final Uri? datasheetUri;

  static AssistantProduct? fromJson(Map<String, dynamic> json) {
    final name = _text(json['name']);
    if (name == null) return null;
    final currency = _text(json['currency'])?.toUpperCase() ?? 'DH';
    final tax = _text(json['price_tax'])?.toUpperCase();
    final uri = Uri.tryParse(_text(json['datasheet_url']) ?? '');
    return AssistantProduct(
      name: name,
      localId: _text(json['id']),
      reference: _text(json['reference']),
      description: _text(json['description']),
      price: _price(json['price']),
      currency: currency == 'MAD' ? 'DH' : currency,
      priceTax: tax == 'TTC' ? 'TTC' : 'HT',
      inStock: _stock(json['en_stock'], json['stock']),
      datasheetUri: uri != null &&
              (uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host.isNotEmpty
          ? uri
          : null,
    );
  }

  static String? _text(dynamic value) {
    if (value is! String && value is! num) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static double? _price(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(
                value.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'))
            : null;
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  static bool? _stock(dynamic available, dynamic quantity) {
    if (available is bool) return available;
    if (available is num) return available > 0;
    if (available is String) {
      switch (available.toLowerCase().trim()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    final stock = quantity is num ? quantity : num.tryParse('$quantity');
    return stock == null ? null : stock > 0;
  }
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    this.suggestedProducts = const [],
    this.offerWhatsApp = false,
  });

  static const unavailable = AssistantReply(
    text:
        'L’assistant est momentanément indisponible. Un conseiller peut vous aider.',
    offerWhatsApp: true,
  );

  /// Preserves the quote marker understood by the existing quote card parser.
  final String text;
  final List<AssistantProduct> suggestedProducts;
  final bool offerWhatsApp;

  static List<AssistantProduct> parseProducts(dynamic raw) {
    if (raw is! List) return const [];
    final products = <AssistantProduct>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final product = AssistantProduct.fromJson(entry);
      if (product != null) products.add(product);
    }
    return List.unmodifiable(products);
  }
}
