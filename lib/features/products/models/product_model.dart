class ProductImage {
  final int id;
  final String url;
  final String? color;
  final String? alt;
  const ProductImage({required this.id, required this.url, this.color, this.alt});
  factory ProductImage.fromJson(Map<String, dynamic> j) =>
      ProductImage(id: j['id'], url: j['url'] ?? '', color: j['color'], alt: j['alt']);
}

class ProductVariant {
  final int id;
  final String? ram;
  final String? storage;
  final double price;       // MRP (original / crossed-out price)
  final double? salePrice;  // Selling price set by admin (null = no discount)
  final int stock;
  final bool inStock;
  final List<String> availableColors;
  final String label;

  const ProductVariant({
    required this.id,
    this.ram,
    this.storage,
    required this.price,
    this.salePrice,
    required this.stock,
    required this.inStock,
    required this.availableColors,
    required this.label,
  });

  /// The actual price the customer pays
  double get currentPrice => salePrice ?? price;

  /// Discount percent, null if no sale price is set
  int? get discountPercent => (salePrice != null && salePrice! < price)
      ? ((1 - salePrice! / price) * 100).round()
      : null;

  factory ProductVariant.fromJson(Map<String, dynamic> j) => ProductVariant(
    id: j['id'],
    ram: j['ram'],
    storage: j['storage'],
    price: (j['price'] as num).toDouble(),
    salePrice: j['sale_price'] != null
        ? (j['sale_price'] as num).toDouble()
        : null,
    stock: j['stock'] ?? 0,
    inStock: j['in_stock'] ?? false,
    availableColors: List<String>.from(j['available_colors'] ?? []),
    label: j['label'] ?? '',
  );
}

class ExchangeOffer {
  final double maxValue;
  final String? terms;
  const ExchangeOffer({required this.maxValue, this.terms});
  factory ExchangeOffer.fromJson(Map<String, dynamic> j) =>
      ExchangeOffer(maxValue: (j['max_value'] as num).toDouble(), terms: j['terms']);

  /// Mirrors the server's ExchangeOffer::calculateValue() exactly, so the
  /// preview shown while filling the form matches what checkout will
  /// actually grant. Without a reference price for the old phone being
  /// traded in, there's nothing to cap the value against, so this
  /// returns 0 rather than the offer's raw uncapped value.
  double calculateValue(String condition, {double? oldPhonePrice}) {
    if (oldPhonePrice == null || oldPhonePrice <= 0) return 0;
    const multipliers = {'excellent': 1.0, 'good': 0.75, 'fair': 0.5, 'poor': 0.25};
    final multiplier = multipliers[condition] ?? 0.5;
    final value = maxValue * multiplier;
    final priceCap = oldPhonePrice * 0.5 * multiplier;
    return value < priceCap ? value : priceCap;
  }
}

class TradeInPriceModel {
  final int id;
  final String brand;
  final String model;
  final double price;
  const TradeInPriceModel({required this.id, required this.brand, required this.model, required this.price});
  factory TradeInPriceModel.fromJson(Map<String, dynamic> j) => TradeInPriceModel(
    id: j['id'], brand: j['brand'], model: j['model'], price: (j['price'] as num).toDouble(),
  );
  String get label => '$brand $model';
}

class CouponModel {
  final String code;
  final String type;
  final double value;
  final String? description;
  final double? maxDiscount;
  final double minOrder;
  final bool productSpecific;
  const CouponModel({required this.code, required this.type, required this.value,
      this.description, this.maxDiscount, required this.minOrder, this.productSpecific = false});
  factory CouponModel.fromJson(Map<String, dynamic> j) => CouponModel(
    code: j['code'], type: j['type'], value: (j['value'] as num).toDouble(),
    description: j['description'],
    maxDiscount: j['max_discount'] != null ? (j['max_discount'] as num).toDouble() : null,
    minOrder: (j['min_order'] as num? ?? 0).toDouble(),
    productSpecific: j['product_specific'] as bool? ?? false,
  );

  String get displayLabel {
    if (type == 'percent') {
      final max = maxDiscount != null ? ' (up to ₹${maxDiscount!.toInt()})' : '';
      return '${value.toInt()}% OFF$max';
    }
    return '₹${value.toInt()} OFF';
  }
}

class ProductModel {
  final int id;
  final String name;
  final String slug;
  final String brandName;
  final String categoryName;
  final String categorySlug;
  final String? shortDescription;
  final String? description;
  final double price;
  final double? salePrice;
  final double currentPrice;
  final int? discountPercent;
  final bool inStock;
  final bool canOrderNow;
  final bool isFeatured;
  final bool isPrebooking;
  final String? expectedDate;
  final String? prebookingNote;
  final List<String> colors;
  final String? thumbnail;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final double avgRating;
  final int reviewCount;
  final ExchangeOffer? exchangeOffer;
  // Specs
  final String? ram;
  final String? storage;
  final String? processor;
  final String? battery;
  final String? cameraMain;
  final String? displaySize;
  final String? displayType;
  final String? network;
  final String? os;

  const ProductModel({required this.id, required this.name, required this.slug,
      required this.brandName, required this.categoryName, required this.categorySlug,
      this.shortDescription, this.description,
      required this.price, this.salePrice, required this.currentPrice,
      this.discountPercent, required this.inStock, required this.canOrderNow,
      required this.isFeatured, this.isPrebooking = false, this.expectedDate, this.prebookingNote,
      required this.colors, this.thumbnail, required this.images,
      required this.variants, required this.avgRating, required this.reviewCount,
      this.exchangeOffer, this.ram, this.storage, this.processor, this.battery,
      this.cameraMain, this.displaySize, this.displayType, this.network, this.os});

  factory ProductModel.fromJson(Map<String, dynamic> j) {
    final specs = j['specs'] as Map<String, dynamic>? ?? {};
    return ProductModel(
      id: j['id'], name: j['name'], slug: j['slug'],
      brandName: j['brand']?['name'] ?? '',
      categoryName: j['category']?['name'] ?? '',
      categorySlug: j['category']?['slug'] ?? '',
      shortDescription: j['short_description'],
      description: j['description'],
      price: (j['price'] as num).toDouble(),
      salePrice: j['sale_price'] != null ? (j['sale_price'] as num).toDouble() : null,
      currentPrice: (j['current_price'] as num).toDouble(),
      discountPercent: j['discount_percent'],
      inStock: j['in_stock'] ?? false,
      canOrderNow: j['can_order_now'] ?? (j['in_stock'] ?? false),
      isFeatured: j['is_featured'] ?? false,
      isPrebooking: j['is_prebooking'] ?? false,
      expectedDate: j['expected_date'],
      prebookingNote: j['prebooking_note'],
      colors: List<String>.from(j['colors'] ?? []),
      thumbnail: j['thumbnail'],
      images: (j['images'] as List? ?? []).map((i) => ProductImage.fromJson(i)).toList(),
      variants: (j['variants'] as List? ?? []).map((v) => ProductVariant.fromJson(v)).toList(),
      avgRating: (j['avg_rating'] as num? ?? 0).toDouble(),
      reviewCount: j['review_count'] ?? 0,
      exchangeOffer: j['exchange_offer'] != null
          ? ExchangeOffer.fromJson(j['exchange_offer']) : null,
      ram: specs['ram'], storage: specs['storage'], processor: specs['processor'],
      battery: specs['battery'], cameraMain: specs['camera_main'],
      displaySize: specs['display_size'], displayType: specs['display_type'],
      network: specs['network'], os: specs['os'],
    );
  }

  // Get color-specific image URLs or fall back to general
  List<String> getImagesForColor(String? color) {
    if (color != null && color.isNotEmpty) {
      final colorImgs = images.where((i) => i.color == color).map((i) => i.url).toList();
      if (colorImgs.isNotEmpty) return colorImgs;
    }
    final general = images.where((i) => i.color == null).map((i) => i.url).toList();
    if (general.isNotEmpty) return general;
    return images.map((i) => i.url).toList();
  }

  String get displayThumbnail => thumbnail ?? '';
}
