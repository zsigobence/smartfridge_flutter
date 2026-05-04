import 'dart:convert';

import 'package:http/http.dart' as http;

class ProductInfo {
  final String name;
  final String? brand;
  final String? imageUrl;

  const ProductInfo({required this.name, this.brand, this.imageUrl});
}

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  Future<ProductInfo?> lookupBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/$barcode.json');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SmartFridgeSync/1.0 (zsigobence@gmail.com)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final product = json['product'] as Map<String, dynamic>;
      final name = (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      return ProductInfo(
        name: name,
        brand: product['brands'] as String?,
        imageUrl: product['image_front_small_url'] as String? ??
            product['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
