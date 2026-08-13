String slugify(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9а-яёүөңэ]+'), '-')
    .replaceAll(RegExp(r'(^-+|-+$)'), '');

int _centsFromPrice(dynamic price) =>
    (double.parse(price.toString()) * 100).round();

class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String?,
    role: j['role'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
  };
}

class Category {
  final int id;
  final String slug;
  final String name;
  final String? emoji;

  Category({
    required this.id,
    required this.slug,
    required this.name,
    this.emoji,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as int,
    slug: slugify(j['name'] as String),
    name: j['name'] as String,
  );
}

class Product {
  final int id;
  final String slug;
  final String name;
  final String? description;
  final int priceCents;
  final int stock;
  final String unit;
  final String? imageUrl;
  final String? badge;
  final int? categoryId;
  final String? categorySlug;
  final String? categoryName;

  Product({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.priceCents,
    this.stock = 0,
    this.unit = 'pcs',
    this.imageUrl,
    this.badge,
    this.categoryId,
    this.categorySlug,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] as int,
    slug: slugify(j['name'] as String),
    name: j['name'] as String,
    description: j['description'] as String?,
    priceCents: _centsFromPrice(j['price']),
    stock: j['stock'] as int? ?? 0,
    imageUrl: j['image_url'] as String?,
    categoryId: j['category_id'] as int?,
    categoryName: j['category_name'] as String?,
  );
}

class CartItem {
  final int productId;
  final String name;
  final String slug;
  final int priceCents;
  final String unit;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.slug,
    required this.priceCents,
    required this.unit,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'slug': slug,
    'price_cents': priceCents,
    'unit': unit,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId: j['product_id'] as int,
    name: j['name'] as String,
    slug: j['slug'] as String? ?? '',
    priceCents: j['price_cents'] as int,
    unit: j['unit'] as String? ?? 'pcs',
    quantity: j['quantity'] as int? ?? 1,
  );

  int get subtotalCents => priceCents * quantity;
}

class Order {
  final int id;
  final String status;
  final int totalCents;
  final DateTime createdAt;
  final String? address;

  Order({
    required this.id,
    required this.status,
    required this.totalCents,
    required this.createdAt,
    this.address,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as int,
    status: j['status'] as String,
    totalCents: _centsFromPrice(j['total']),
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    address: j['address'] as String?,
  );

  // Заказ ещё не завершён (курьер не доставил, всё не отменено) — используется,
  // чтобы решить, показывать ли живое отслеживание или просто запись в истории.
  bool get isActive =>
      status != 'delivered' && status != 'completed' && status != 'cancelled';
}

class Address {
  final int id;
  final String? label;
  final String addressText;
  final double? lat;
  final double? lng;
  final bool isDefault;

  Address({
    required this.id,
    this.label,
    required this.addressText,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> j) => Address(
    id: j['id'] as int,
    label: j['label'] as String?,
    addressText: j['address_text'] as String,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    isDefault: j['is_default'] as bool? ?? false,
  );
}

class NotificationItem {
  final int id;
  final String title;
  final String? message;
  final bool read;
  final int? orderId;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    this.message,
    required this.read,
    this.orderId,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: j['id'] as int,
    title: j['title'] as String,
    message: j['message'] as String?,
    read: j['read'] as bool? ?? false,
    orderId: j['order_id'] as int?,
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
