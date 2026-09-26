import '../../cart/domain/cart_item.dart';

class CheckoutLineRequest {
  const CheckoutLineRequest({
    required this.productId,
    required this.quantity,
    this.productAttributeId = 0,
  });

  final int productId;
  final int quantity;
  final int productAttributeId;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_attribute_id': productAttributeId,
        'quantity': quantity,
      };

  static List<CheckoutLineRequest> fromCart(List<CartItem> items) {
    return [
      for (final item in items)
        CheckoutLineRequest(
          productId: item.product.id,
          quantity: item.quantity,
        ),
    ];
  }
}

class CheckoutPreview {
  const CheckoutPreview({
    required this.lines,
    required this.totals,
    required this.carriers,
    required this.payments,
    required this.selectedCarrierId,
    required this.stockOk,
    required this.writeEnabled,
    required this.bridgeRequired,
  });

  final List<CheckoutLine> lines;
  final CheckoutTotals totals;
  final List<CheckoutCarrier> carriers;
  final List<CheckoutPayment> payments;
  final int? selectedCarrierId;
  final bool stockOk;
  final bool writeEnabled;
  final List<String> bridgeRequired;

  factory CheckoutPreview.fromJson(Map<String, dynamic> json) {
    return CheckoutPreview(
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CheckoutLine.fromJson)
          .toList(),
      totals: CheckoutTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? const {}),
      ),
      carriers: (json['carriers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CheckoutCarrier.fromJson)
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CheckoutPayment.fromJson)
          .toList(),
      selectedCarrierId: (json['selected_carrier_id'] as num?)?.toInt(),
      stockOk: json['stock_ok'] == true,
      writeEnabled: json['write_enabled'] == true,
      bridgeRequired: (json['bridge_required'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class CheckoutLine {
  const CheckoutLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.currency,
    required this.currencySymbol,
    required this.available,
    this.stockQuantity,
    this.stockMessage,
  });

  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;
  final String currency;
  final String currencySymbol;
  final bool available;
  final int? stockQuantity;
  final String? stockMessage;

  factory CheckoutLine.fromJson(Map<String, dynamic> json) {
    return CheckoutLine(
      productId: (json['product_id'] as num? ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      unitPrice: (json['unit_price'] as num? ?? 0).toDouble(),
      total: (json['total'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'MAD').toString(),
      currencySymbol:
          (json['currency_symbol'] ?? json['currency'] ?? 'MAD').toString(),
      available: json['available'] == true,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt(),
      stockMessage: json['stock_message']?.toString(),
    );
  }
}

class CheckoutCarrier {
  const CheckoutCarrier({
    required this.id,
    required this.name,
    this.delay,
    this.priceLabel,
  });

  final int id;
  final String name;
  final String? delay;
  final String? priceLabel;

  factory CheckoutCarrier.fromJson(Map<String, dynamic> json) {
    return CheckoutCarrier(
      id: (json['id'] as num? ?? 0).toInt(),
      name: (json['name'] ?? '').toString(),
      delay: json['delay']?.toString(),
      priceLabel: json['price_label']?.toString(),
    );
  }
}

class CheckoutPayment {
  const CheckoutPayment({
    required this.module,
    required this.name,
  });

  final String module;
  final String name;

  factory CheckoutPayment.fromJson(Map<String, dynamic> json) {
    return CheckoutPayment(
      module: (json['module'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class CheckoutTotals {
  const CheckoutTotals({
    required this.subtotal,
    required this.shippingLabel,
    required this.discounts,
    required this.totalTtc,
    required this.currency,
    required this.currencySymbol,
  });

  final double subtotal;
  final String shippingLabel;
  final double discounts;
  final double totalTtc;
  final String currency;
  final String currencySymbol;

  factory CheckoutTotals.fromJson(Map<String, dynamic> json) {
    return CheckoutTotals(
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      shippingLabel: (json['shipping_label'] ?? '').toString(),
      discounts: (json['discounts'] as num? ?? 0).toDouble(),
      totalTtc: (json['total_ttc'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'MAD').toString(),
      currencySymbol:
          (json['currency_symbol'] ?? json['currency'] ?? 'MAD').toString(),
    );
  }
}

class CheckoutConfirmResult {
  const CheckoutConfirmResult({
    this.orderId,
    this.reference,
    this.total,
    this.currency,
    this.status,
    this.paymentDetails,
  });

  final int? orderId;
  final String? reference;
  final double? total;
  final String? currency;
  final String? status;
  final BankWireDetails? paymentDetails;

  factory CheckoutConfirmResult.fromJson(Map<String, dynamic> json) {
    return CheckoutConfirmResult(
      orderId: (json['order_id'] as num?)?.toInt(),
      reference: json['reference']?.toString(),
      total: (json['total'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
      status: json['status']?.toString(),
      paymentDetails: json['payment_details'] is Map
          ? BankWireDetails.fromJson(
              Map<String, dynamic>.from(json['payment_details'] as Map),
            )
          : null,
    );
  }
}

class BankWireDetails {
  const BankWireDetails({
    this.owner,
    this.details,
    this.address,
    this.phone,
    this.reservationDays,
    this.customText,
  });

  final String? owner;
  final String? details;
  final String? address;
  final String? phone;
  final int? reservationDays;
  final String? customText;

  factory BankWireDetails.fromJson(Map<String, dynamic> json) {
    return BankWireDetails(
      owner: json['owner']?.toString(),
      details: json['details']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      reservationDays: (json['reservation_days'] as num?)?.toInt(),
      customText: json['custom_text']?.toString(),
    );
  }
}
