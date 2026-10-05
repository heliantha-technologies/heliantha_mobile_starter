import '../../../shared/models/product.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  double get total => product.price * quantity;

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        'product': {
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'currency': product.currency,
          'currency_symbol': product.currencySymbol,
          'currency_id': product.currencyId,
          'available': product.available,
          'reference': product.reference,
          'quantity': product.quantity,
          'description_short': product.descriptionShort,
          'description': product.description,
          'technical_details': product.technicalDetails,
          'category_id': product.categoryId,
          'image_url': product.imageUrl,
          'features': [
            for (final feature in product.features)
              {'name': feature.name, 'value': feature.value},
          ],
        },
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num).toInt();
    final product = Product.fromJson(
      Map<String, dynamic>.from(json['product'] as Map),
    );
    if (quantity <= 0 ||
        product.id <= 0 ||
        !product.price.isFinite ||
        product.price < 0 ||
        product.currency.trim().isEmpty) {
      throw const FormatException('Invalid saved cart item');
    }
    return CartItem(product: product, quantity: quantity);
  }

  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
