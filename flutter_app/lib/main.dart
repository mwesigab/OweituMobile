import 'package:flutter/material.dart';

void main() {
  runApp(const OweituApp());
}

double fs(BuildContext context, double size) {
  final w = MediaQuery.of(context).size.width;
  return (size * w / 390).clamp(size * 0.82, size * 1.18);
}

class OweituApp extends StatefulWidget {
  const OweituApp({super.key});

  @override
  State<OweituApp> createState() => _OweituAppState();
}

class _OweituAppState extends State<OweituApp> {
  final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Oweitu Cafe',
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.sage,
                primary: AppColors.sage,
                secondary: AppColors.coral,
                surface: Colors.white,
              ),
              scaffoldBackgroundColor: const Color(0xFFFAF8F5),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.08,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.04,
                  ),
                ),
              ),
            ),
            home: state.isAuthenticated
                ? const HomeShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}

// ─── STATE ───────────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  final List<Order> orders = [];
  final List<CartItem> cart = [];
  final Set<String> favorites = {};
  DeliveryAddress? selectedAddress;
  String? promoCodeApplied;
  int promoDiscountAmount = 0;

  int get itemCount => cart.length;
  int get cartSubtotal => cart.fold(0, (sum, i) => sum + i.total);
  int get cartTotal => (cartSubtotal - promoDiscountAmount).clamp(0, 999999999);

  void signIn() {
    isAuthenticated = true;
    notifyListeners();
  }

  void signOut() {
    isAuthenticated = false;
    cart.clear();
    favorites.clear();
    orders.clear();
    selectedAddress = null;
    promoCodeApplied = null;
    promoDiscountAmount = 0;
    notifyListeners();
  }

  void addToCart(MenuItem item, {String? note}) {
    final existing = cart
        .where((c) => c.name == item.name && c.note == note)
        .toList();
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      cart.add(CartItem(name: item.name, price: item.price, note: note));
    }
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    if (item.qty > 1) {
      item.qty--;
    } else {
      cart.remove(item);
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    promoCodeApplied = null;
    promoDiscountAmount = 0;
    notifyListeners();
  }

  void toggleFavorite(String itemName) {
    if (favorites.contains(itemName)) {
      favorites.remove(itemName);
    } else {
      favorites.add(itemName);
    }
    notifyListeners();
  }

  bool isFavorite(String itemName) => favorites.contains(itemName);

  void setAddress(DeliveryAddress address) {
    selectedAddress = address;
    notifyListeners();
  }

  /// Returns true if promo was valid
  bool applyPromo(String code) {
    // TODO: validate against .NET backend — POST /api/promos/validate
    final upper = code.trim().toUpperCase();
    if (upper == 'OWEITU10') {
      promoCodeApplied = upper;
      promoDiscountAmount = (cartSubtotal * 0.10).round();
      notifyListeners();
      return true;
    }
    if (upper == 'WELCOME20') {
      promoCodeApplied = upper;
      promoDiscountAmount = (cartSubtotal * 0.20).round();
      notifyListeners();
      return true;
    }
    return false;
  }

  void removePromo() {
    promoCodeApplied = null;
    promoDiscountAmount = 0;
    notifyListeners();
  }

  void placeOrder() {
    // TODO: POST /api/orders with cart + address + promo
    final id = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    orders.insert(
      0,
      Order(
        id: id,
        items: List.from(cart),
        total: cartTotal,
        address: selectedAddress?.label ?? 'Not specified',
        placedAt: DateTime.now(),
        status: OrderStatus.placed,
      ),
    );
    clearCart();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ─── MODELS ──────────────────────────────────────────────────────────────────

class MenuItem {
  const MenuItem({
    required this.name,
    required this.price,
    this.note,
    this.imagePath,
    this.description,
    this.tags = const [],
    this.isPopular = false,
    this.isNew = false,
    this.prepTimeMinutes,
    this.calories,
  });
  final String name;
  final int price;
  final String? note;
  final String? imagePath;
  final String? description;
  final List<String> tags;
  final bool isPopular;
  final bool isNew;
  final int? prepTimeMinutes;
  final int? calories;

  String get priceFormatted => 'UGX ${_fmt(price)}';
  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

class PizzaItem {
  const PizzaItem({
    required this.name,
    required this.small,
    required this.medium,
    required this.large,
    this.imagePath,
    this.description,
    this.isPopular = false,
  });
  final String name;
  final int small, medium, large;
  final String? imagePath;
  final String? description;
  final bool isPopular;

  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  String get smallFormatted => 'UGX ${_fmt(small)}';
  String get mediumFormatted => 'UGX ${_fmt(medium)}';
  String get largeFormatted => 'UGX ${_fmt(large)}';
}

class CartItem {
  CartItem({required this.name, required this.price, this.qty = 1, this.note});
  final String name;
  final int price;
  int qty;
  final String? note;
  int get total => price * qty;
}

enum OrderStatus {
  placed,
  confirmed,
  preparing,
  onTheWay,
  delivered,
  cancelled,
}

class Order {
  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.address,
    required this.placedAt,
    this.status = OrderStatus.placed,
    this.estimatedMinutes,
  });
  final String id;
  final List<CartItem> items;
  final int total;
  final String address;
  final DateTime placedAt;
  OrderStatus status;
  final int? estimatedMinutes;

  String get statusLabel {
    switch (status) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Being Prepared';
      case OrderStatus.onTheWay:
        return 'On the Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData get statusIcon {
    switch (status) {
      case OrderStatus.placed:
        return Icons.receipt_long_outlined;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.outdoor_grill_outlined;
      case OrderStatus.onTheWay:
        return Icons.delivery_dining_outlined;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

class DeliveryAddress {
  DeliveryAddress({
    required this.label,
    required this.fullAddress,
    this.instructions,
    this.isDefault = false,
  });
  final String label;
  final String fullAddress;
  final String? instructions;
  final bool isDefault;
}

// ─── API SERVICE LAYER (ready for .NET backend) ──────────────────────────────
// All methods are stubs — wire up to your C# .NET REST API.
// Base URL should be set from environment/config.

class ApiService {
  static const String baseUrl =
      'https://api.oweitu.com'; // TODO: set from config

  // AUTH
  // POST /api/auth/login
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/login');
  }

  // POST /api/auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String identifier,
    required String password,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/register');
  }

  // POST /api/auth/social
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/social');
  }

  // POST /api/auth/forgot-password
  static Future<void> forgotPassword({required String identifier}) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/forgot-password');
  }

  // MENU
  // GET /api/menu/categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/categories');
  }

  // GET /api/menu/items?categoryId={id}
  static Future<List<Map<String, dynamic>>> getMenuItems({
    String? categoryId,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/items');
  }

  // GET /api/menu/search?q={query}
  static Future<List<Map<String, dynamic>>> searchMenu({
    required String query,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/search?q=$query');
  }

  // GET /api/menu/featured
  static Future<List<Map<String, dynamic>>> getFeaturedItems() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/featured');
  }

  // ORDERS
  // POST /api/orders
  static Future<Map<String, dynamic>> placeOrder({
    required List<CartItem> items,
    required String addressId,
    String? promoCode,
    String? paymentMethod,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/orders');
  }

  // GET /api/orders?userId={id}
  static Future<List<Map<String, dynamic>>> getOrderHistory() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/orders');
  }

  // GET /api/orders/{id}/track
  static Future<Map<String, dynamic>> trackOrder({
    required String orderId,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/orders/$orderId/track');
  }

  // ADDRESSES
  // GET /api/addresses
  static Future<List<Map<String, dynamic>>> getAddresses() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/addresses');
  }

  // POST /api/addresses
  static Future<Map<String, dynamic>> saveAddress({
    required String label,
    required String fullAddress,
    String? instructions,
    bool isDefault = false,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/addresses');
  }

  // DELETE /api/addresses/{id}
  static Future<void> deleteAddress({required String id}) async {
    throw UnimplementedError('Wire to DELETE $baseUrl/api/addresses/$id');
  }

  // PROMOS
  // POST /api/promos/validate
  static Future<Map<String, dynamic>> validatePromo({
    required String code,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/promos/validate');
  }

  // FAVORITES
  // GET /api/favorites
  static Future<List<String>> getFavorites() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/favorites');
  }

  // POST /api/favorites
  static Future<void> toggleFavorite({required String itemName}) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/favorites');
  }

  // NOTIFICATIONS
  // GET /api/notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/notifications');
  }

  // POST /api/notifications/{id}/read
  static Future<void> markNotificationRead({
    required String notificationId,
  }) async {
    throw UnimplementedError(
      'Wire to POST $baseUrl/api/notifications/$notificationId/read',
    );
  }

  // PROFILE
  // GET /api/profile
  static Future<Map<String, dynamic>> getProfile() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/profile');
  }

  // PUT /api/profile
  static Future<void> updateProfile({
    required Map<String, dynamic> data,
  }) async {
    throw UnimplementedError('Wire to PUT $baseUrl/api/profile');
  }

  // REVIEWS
  // POST /api/reviews
  static Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/reviews');
  }

  // BRANCHES
  // GET /api/branches
  static Future<List<Map<String, dynamic>>> getBranches() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/branches');
  }

  // REWARDS / LOYALTY
  // GET /api/rewards/points
  static Future<Map<String, dynamic>> getRewardsPoints() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/rewards/points');
  }

  // GET /api/rewards/history
  static Future<List<Map<String, dynamic>>> getRewardsHistory() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/rewards/history');
  }

  // PAYMENTS
  // POST /api/payments/initialize
  static Future<Map<String, dynamic>> initializePayment({
    required int amount,
    required String method,
    required String orderId,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/payments/initialize');
  }

  // GIFT CARDS
  // POST /api/giftcards/send
  static Future<void> sendGiftCard({
    required String recipientPhone,
    required int amount,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/giftcards/send');
  }

  // POST /api/giftcards/redeem
  static Future<Map<String, dynamic>> redeemGiftCard({
    required String code,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/giftcards/redeem');
  }
}

// ─── MENU DATA ───────────────────────────────────────────────────────────────

const snacks = [
  MenuItem(name: 'Chips, 2 Pcs of Chicken and a Soda', price: 17000),
  MenuItem(name: 'Chips, 3 Pcs of Chicken and a Soda', price: 23000),
  MenuItem(name: 'Chips, 4 Pcs of Chicken and a Soda', price: 27000),
  MenuItem(name: '5 Pcs Chicken, 2 Regular Chips & 2 Drinks', price: 35000),
  MenuItem(name: 'Chips Liver and Drink', price: 14000),
  MenuItem(name: 'Chips Beef and Drink', price: 14000),
  MenuItem(name: 'Stewed Rice, Liver and Drink', price: 14000),
  MenuItem(name: 'Stewed Rice, Beef and Drink', price: 14000),
  MenuItem(name: 'Pair of Sausages, Chips and Drink', price: 11000),
  MenuItem(name: 'Whole Fish, Chips and Drink', price: 26000),
  MenuItem(name: 'Chips, 1 Chap and 1 Drink', price: 12000),
  MenuItem(name: 'Palau Beef and a Drink', price: 14000),
  MenuItem(name: 'Chicken / Beef Burger, Chips and Drink', price: 25000),
  MenuItem(name: 'Chips, Goats Meat and a Drink', price: 17000),
  MenuItem(
    name: 'Half Chips, Half Rice with Liver / Gravy / Beef',
    price: 16000,
  ),
  MenuItem(name: 'Beef / Liver Plain', price: 7000),
  MenuItem(name: 'Plain Chips', price: 7000),
  MenuItem(name: 'Fish Fillet Plain (2 Pcs)', price: 11000),
  MenuItem(name: 'Pilawo Plain', price: 7000),
  MenuItem(name: 'Plain Chicken', price: 9000),
];

const breakfast = [
  MenuItem(
    name: 'Katogo Vegetables',
    price: 6000,
    imagePath: 'assets/images/Katogo Vegetables.jpg',
  ),
  MenuItem(
    name: 'Katogo Beef / Liver',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/ Liver.jpg',
  ),
  MenuItem(
    name: 'A Pair of Beef Samosa',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Beef Samosa.jpg',
  ),
  MenuItem(
    name: 'Plain Omelette',
    price: 2500,
    imagePath: 'assets/images/Katogo Beef/Plain Omelette.jpg',
  ),
  MenuItem(
    name: 'Spanish Omelette',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Spanish Omelette.jpg',
  ),
  MenuItem(
    name: 'Chapati and Beans',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Chapati and Beans.jpg',
  ),
  MenuItem(
    name: 'Plain Chapati',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Plain Chapatti.jpg',
  ),
  MenuItem(name: 'Chapati and Gravy', price: 3000),
  MenuItem(
    name: 'Kebab Plain',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Kebab Plain.jpg',
  ),
  MenuItem(
    name: 'Chaps Plain',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Chap Plain.jpg',
  ),
  MenuItem(
    name: 'A Pair of Sausage Plain',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Pair of Sausage.jpg',
  ),
  MenuItem(
    name: 'Beef Sandwich',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/Beef Sandwich.jpg',
  ),
  MenuItem(
    name: 'Chicken Sandwich',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/chicken sandwich.jpg',
  ),
  MenuItem(
    name: 'Eggs Sandwich',
    price: 5000,
    imagePath: 'assets/images/Katogo Beef/Egg Sandwich.jpg',
  ),
];

const burgers = [
  MenuItem(
    name: 'Plain Chicken Burger',
    price: 13000,
    imagePath: 'assets/images/Chicken Burger.jpg',
  ),
  MenuItem(
    name: 'Beef Burger Plain',
    price: 11000,
    imagePath: 'assets/images/Beef Burger.jpg',
  ),
  MenuItem(
    name: 'Vegetable Burger Plain',
    price: 9000,
    imagePath: 'assets/images/Vegetable Burger.jpg',
  ),
  MenuItem(
    name: 'Cheese Burger',
    price: 9000,
    imagePath: 'assets/images/Cheese Burger.jpg',
  ),
];

const drinks = [
  MenuItem(
    name: 'Minute Maid',
    price: 3000,
    imagePath: 'assets/images/Minute Maid.jpg',
  ),
  MenuItem(name: 'Soda', price: 2000, imagePath: 'assets/images/Soda.jpg'),
  MenuItem(name: 'Water', price: 2000, imagePath: 'assets/images/Water.jpg'),
  MenuItem(
    name: 'Mixed Passion and Mangoes Juice',
    price: 4000,
    imagePath: 'assets/images/Mixed passion & mango.jpg',
  ),
];

const teas = [
  MenuItem(
    name: 'Black Tea',
    price: 3000,
    imagePath: 'assets/images/Black Tea.jpg',
  ),
  MenuItem(
    name: 'African Tea',
    price: 4000,
    imagePath: 'assets/images/African Tea.jpg',
  ),
  MenuItem(
    name: 'Herbal Tea',
    price: 5000,
    imagePath: 'assets/images/Herbal Tea.jpg',
  ),
  MenuItem(
    name: 'Hot Chocolate',
    price: 6000,
    imagePath: 'assets/images/Hot Chocolate.jpg',
  ),
  MenuItem(
    name: 'English Tea (Hot Water & Milk Aside)',
    price: 6000,
    imagePath: 'assets/images/English Tea.jpg',
  ),
  MenuItem(
    name: 'Tea Masala',
    price: 5000,
    imagePath: 'assets/images/Tea Masala.jpg',
  ),
  MenuItem(
    name: 'Dawa Tea (Lemon, Ginger, Cinnamon & Honey)',
    price: 6000,
    imagePath: 'assets/images/Dawa Tea.jpg',
  ),
  MenuItem(
    name: 'Iced Tea',
    price: 4000,
    imagePath: 'assets/images/Iced Tea.jpg',
  ),
];

const pizzas = [
  PizzaItem(
    name: 'Chicken Tikka Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/ChickenTikka.jpg',
  ),
  PizzaItem(
    name: 'Chicken BBQ Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Chicken BBq.jpg',
  ),
  PizzaItem(
    name: 'Chicken and Mushroom Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Chicken Mushroom.jpg',
  ),
  PizzaItem(
    name: 'Beef Tikka Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/BeefTikka.jpg',
  ),
  PizzaItem(
    name: 'Vegetable Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Vegetable Pizza.jpg',
  ),
  PizzaItem(
    name: 'Hawaiian Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Hawaiin Pizza.jpg',
  ),
  PizzaItem(
    name: 'Margherita Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Margherita Pizza.jpg',
  ),
  PizzaItem(
    name: 'Oweitu Pizza Special',
    small: 27000,
    medium: 35000,
    large: 40000,
    imagePath: 'assets/images/Oweitu Special.jpg',
  ),
];

// Flat list of all items for search
List<MenuItem> get allMenuItems {
  final List<MenuItem> all = [
    ...snacks,
    ...breakfast,
    ...burgers,
    ...drinks,
    ...teas,
  ];
  // Add pizzas (small price as representative)
  for (final p in pizzas) {
    all.add(
      MenuItem(
        name: p.name,
        price: p.small,
        imagePath: p.imagePath,
        note: 'from',
      ),
    );
  }
  return all;
}

// ─── MENU CATEGORY DEFINITIONS ───────────────────────────────────────────────

class MenuCategoryDef {
  const MenuCategoryDef({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.imagePath,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String imagePath;
}

const menuCategories = [
  MenuCategoryDef(
    label: 'SNACKS & MAINS',
    subtitle: 'Chips, Rice, Fish & More',
    icon: Icons.lunch_dining,
    accentColor: Color(0xFFE8433D),
    imagePath: 'assets/images/Chicken and Chips.jpg',
  ),
  MenuCategoryDef(
    label: 'BIG BREAKFAST',
    subtitle: 'Katogo, Omelettes & Sandwiches',
    icon: Icons.breakfast_dining,
    accentColor: Color(0xFFF5A623),
    imagePath: 'assets/images/Rolex.jpg',
  ),
  MenuCategoryDef(
    label: 'BURGERS',
    subtitle: 'Chicken, Beef & Veg',
    icon: Icons.lunch_dining_outlined,
    accentColor: Color(0xFF8FA882),
    imagePath: 'assets/images/Chicken Burger.jpg',
  ),
  MenuCategoryDef(
    label: 'COLD DRINKS',
    subtitle: 'Juices, Sodas & Water',
    icon: Icons.local_drink,
    accentColor: Color(0xFF0A3352),
    imagePath: 'assets/images/Minute Maid.jpg',
  ),
  MenuCategoryDef(
    label: 'HOT TEAS',
    subtitle: 'African, Herbal, Masala & More',
    icon: Icons.local_cafe,
    accentColor: Color(0xFF8FA882),
    imagePath: 'assets/images/Tea Masala.jpg',
  ),
  MenuCategoryDef(
    label: 'PIZZA',
    subtitle: 'Small, Medium & Large',
    icon: Icons.local_pizza,
    accentColor: Color(0xFFE8433D),
    imagePath: 'assets/images/ChickenTikka.jpg',
  ),
];

// ─── AUTH SCREEN (Sign In / Sign Up) ─────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset('assets/images/Login.jpg', fit: BoxFit.cover),
          // Dark gradient scrim — heavier at bottom where the card sits
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000),
                  Color(0xCC000000),
                  Color(0xEE000000),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  // Brand
                  Text(
                    'Oweitu Cafe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fs(context, 42),
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CAFÉ & RESTAURANT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: fs(context, 11),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.14,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tab bar: Sign In | Sign Up
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Container(
                            color: const Color(0xFFF5F5F5),
                            child: TabBar(
                              controller: _tabs,
                              labelColor: Colors.white,
                              unselectedLabelColor: AppColors.mutedText,
                              indicator: BoxDecoration(color: AppColors.sage),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelStyle: TextStyle(
                                fontSize: fs(context, 13),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.06,
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontSize: fs(context, 13),
                                fontWeight: FontWeight.w600,
                              ),
                              tabs: const [
                                Tab(text: 'SIGN IN'),
                                Tab(text: 'SIGN UP'),
                              ],
                            ),
                          ),
                        ),

                        // Tab content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: _tabs.index == 0
                              ? _SignInForm(
                                  onSignIn: () => AppScope.of(context).signIn(),
                                )
                              : _SignUpForm(
                                  onSignUp: () => AppScope.of(context).signIn(),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OR divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Colors.white30, thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fs(context, 12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Colors.white30, thickness: 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Social buttons — row 1
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Google',
                          color: Colors.white,
                          textColor: const Color(0xFF3C4043),
                          borderColor: const Color(0xFFDDDDDD),
                          icon: _GoogleIcon(),
                          onTap: () => AppScope.of(context).signIn(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialButton(
                          label: 'Facebook',
                          color: const Color(0xFF1877F2),
                          textColor: Colors.white,
                          icon: const Icon(
                            Icons.facebook,
                            color: Colors.white,
                            size: 18,
                          ),
                          onTap: () => AppScope.of(context).signIn(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Social buttons — row 2
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'TikTok',
                          color: Colors.black,
                          textColor: Colors.white,
                          icon: _TikTokIcon(),
                          onTap: () => AppScope.of(context).signIn(),
                        ),
                      ),
                      // Empty right slot keeps TikTok at half-width like siblings
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: fs(context, 10),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SIGN IN FORM ─────────────────────────────────────────────────────────────

class _SignInForm extends StatelessWidget {
  const _SignInForm({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back 👋',
          style: TextStyle(
            fontSize: fs(context, 18),
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: fs(context, 12),
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 18),
        const _InputField(hint: 'Email or phone number'),
        const SizedBox(height: 10),
        const _InputField(hint: 'Password', obscure: true),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: fs(context, 12),
                color: AppColors.sage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: onSignIn,
            child: const Text('Sign In'),
          ),
        ),
      ],
    );
  }
}

// ─── SIGN UP FORM ─────────────────────────────────────────────────────────────

class _SignUpForm extends StatefulWidget {
  const _SignUpForm({required this.onSignUp});
  final VoidCallback onSignUp;

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  bool _usePhone = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create account 🎉',
          style: TextStyle(
            fontSize: fs(context, 18),
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Join Oweitu and start ordering',
          style: TextStyle(
            fontSize: fs(context, 12),
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 18),
        const _InputField(hint: 'Full name'),
        const SizedBox(height: 10),

        // Email / Phone toggle pill
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usePhone = false),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: !_usePhone ? AppColors.sage : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          fontWeight: FontWeight.w700,
                          color: !_usePhone
                              ? Colors.white
                              : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usePhone = true),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: _usePhone ? AppColors.sage : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'Phone',
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          fontWeight: FontWeight.w700,
                          color: _usePhone ? Colors.white : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        _InputField(
          hint: _usePhone
              ? 'Phone number (e.g. +256 7xx xxx xxx)'
              : 'Email address',
          keyboardType: _usePhone
              ? TextInputType.phone
              : TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        const _InputField(hint: 'Password', obscure: true),
        const SizedBox(height: 10),
        const _InputField(hint: 'Confirm password', obscure: true),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: widget.onSignUp,
            child: const Text('Create Account'),
          ),
        ),
      ],
    );
  }
}

// ─── FORGOT PASSWORD SCREEN ───────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RESET PASSWORD'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _sent ? _sentView() : _formView(),
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.lock_reset, size: 56, color: AppColors.sage),
        const SizedBox(height: 20),
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(context, 20),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email or phone number and we'll send you a reset link.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(context, 13),
            color: AppColors.mutedText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        const _InputField(hint: 'Email or phone number'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // TODO: call ApiService.forgotPassword()
            setState(() => _sent = true);
          },
          child: const Text('Send Reset Link'),
        ),
      ],
    );
  }

  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.sage),
        const SizedBox(height: 20),
        Text(
          'Check your inbox!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(context, 20),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A password reset link has been sent. Check your email or SMS inbox.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fs(context, 13),
            color: AppColors.mutedText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}

// ─── SOCIAL BUTTON ────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
    this.borderColor,
  });
  final String label;
  final Color color;
  final Color textColor;
  final Widget icon;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x25000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: fs(context, 12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CUSTOM ICONS (no external packages) ─────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.57,
      1.57,
      false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.22
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14,
      0.79,
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..strokeWidth = size.width * 0.22
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.93,
      0.79,
      false,
      Paint()
        ..color = const Color(0xFFFBBC04)
        ..strokeWidth = size.width * 0.22
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      4.71,
      0.79,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..strokeWidth = size.width * 0.22
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        cx,
        cy - size.height * 0.12,
        cx + r + 1,
        cy + size.height * 0.12,
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx + r * 0.55, cy),
      size.width * 0.11,
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TikTokIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _TikTokPainter()),
    );
  }
}

class _TikTokPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawNote(canvas, w, h, const Color(0xFF69C9D0), Offset(w * 0.08, 0));
    _drawNote(
      canvas,
      w,
      h,
      const Color(0xFFEE1D52),
      Offset(-w * 0.08, h * 0.06),
    );
    _drawNote(canvas, w, h, Colors.white, Offset.zero);
  }

  void _drawNote(
    Canvas canvas,
    double w,
    double h,
    Color color,
    Offset offset,
  ) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          w * 0.28 + offset.dx,
          h * 0.04 + offset.dy,
          w * 0.20,
          h * 0.72,
        ),
        Radius.circular(w * 0.06),
      ),
      paint,
    );
    canvas.drawCircle(
      Offset(w * 0.25 + offset.dx, h * 0.76 + offset.dy),
      w * 0.19,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          w * 0.44 + offset.dx,
          h * 0.04 + offset.dy,
          w * 0.50,
          h * 0.30,
        ),
        Radius.circular(w * 0.10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── INPUT FIELD ─────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.controller,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
  });
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      keyboardType: keyboardType,
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(fontSize: fs(context, 14), color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: fs(context, 13),
          color: AppColors.mutedText,
        ),
        filled: true,
        fillColor: const Color(0xFFFAF8F5),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
        ),
      ),
    );
  }
}

// ─── SHELL ───────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tabIndex = 0;
  void selectTab(int i) => setState(() => tabIndex = i);

  @override
  Widget build(BuildContext context) {
    final titles = ['HOME', 'MENU', 'REWARDS', 'MORE'];
    final pages = [
      HomeScreen(onStartOrder: () => selectTab(1)),
      const MenuScreen(),
      const RewardsScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tabIndex]),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Notification bell — always visible
          _NotificationBell(),
          if (tabIndex == 1)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => _showCart(context),
                ),
                if (AppScope.of(context).itemCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${AppScope.of(context).itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),
      body: pages[tabIndex],
      bottomNavigationBar: AppBottomNav(
        selectedIndex: tabIndex,
        onChanged: selectTab,
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AppScope(state: AppScope.of(context), child: const CartSheet()),
    );
  }
}

// ─── NOTIFICATION BELL ────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: replace count with real unread count from AppState/ApiService
    const int unreadCount = 2;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppScope(
                state: AppScope.of(context),
                child: const NotificationsScreen(),
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── CART SHEET ──────────────────────────────────────────────────────────────

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final TextEditingController _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cart = state.cart;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Your Order',
                  style: TextStyle(
                    fontSize: fs(context, 18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${cart.length} item${cart.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (cart.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: fs(context, 14),
                  color: AppColors.mutedText,
                ),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.length,
                itemBuilder: (_, i) {
                  final item = cart[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: fs(context, 13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    MenuItem._fmt(item.price) + ' UGX',
                                    style: TextStyle(
                                      fontSize: fs(context, 11),
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                  if (item.note != null &&
                                      item.note!.isNotEmpty)
                                    Text(
                                      '📝 ${item.note}',
                                      style: TextStyle(
                                        fontSize: fs(context, 10),
                                        color: AppColors.grayText,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _QtyBtn(
                                  icon: Icons.remove,
                                  onTap: () => state.removeFromCart(item),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    '${item.qty}',
                                    style: TextStyle(
                                      fontSize: fs(context, 14),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _QtyBtn(
                                  icon: Icons.add,
                                  onTap: () => state.addToCart(
                                    MenuItem(
                                      name: item.name,
                                      price: item.price,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Delivery Address selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: () => _pickAddress(context, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFFAF8F5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.sage,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.selectedAddress?.label ??
                              'Add delivery address',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            fontWeight: FontWeight.w600,
                            color: state.selectedAddress != null
                                ? AppColors.textDark
                                : AppColors.mutedText,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Promo code row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: state.promoCodeApplied != null
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${state.promoCodeApplied} applied!',
                                    style: TextStyle(
                                      fontSize: fs(context, 12),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => state.removePromo(),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _InputField(
                            hint: 'Promo code',
                            controller: _promoController,
                            prefixIcon: Icon(
                              Icons.local_offer_outlined,
                              size: 16,
                              color: AppColors.mutedText,
                            ),
                          ),
                  ),
                  if (state.promoCodeApplied == null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          final code = _promoController.text;
                          if (!state.applyPromo(code)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid promo code'),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Apply',
                          style: TextStyle(fontSize: fs(context, 12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(color: AppColors.line),

            // Order summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          color: AppColors.mutedText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'UGX ${MenuItem._fmt(state.cartSubtotal)}',
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  if (state.promoDiscountAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Discount',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: Colors.green.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '- UGX ${MenuItem._fmt(state.promoDiscountAmount)}',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: fs(context, 15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'UGX ${MenuItem._fmt(state.cartTotal)}',
                        style: TextStyle(
                          fontSize: fs(context, 15),
                          fontWeight: FontWeight.w800,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: AppScope.of(context),
                        child: const CheckoutScreen(),
                      ),
                    ),
                  );
                },
                child: const Text('Proceed to Checkout'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _pickAddress(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppScope(state: state, child: const AddressPickerSheet()),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.sage),
      ),
    );
  }
}

// ─── ADDRESS PICKER SHEET ────────────────────────────────────────────────────

class AddressPickerSheet extends StatelessWidget {
  const AddressPickerSheet({super.key});

  // TODO: load real saved addresses from ApiService.getAddresses()
  static final List<DeliveryAddress> _sampleAddresses = [
    DeliveryAddress(
      label: 'Home',
      fullAddress: 'Plot 14, Bukoto Street, Kampala',
      isDefault: true,
    ),
    DeliveryAddress(
      label: 'Work',
      fullAddress: 'Workers House, Pilkington Road, Kampala',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: fs(context, 16),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ..._sampleAddresses.map(
            (addr) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.sage,
                ),
              ),
              title: Text(
                addr.label,
                style: TextStyle(
                  fontSize: fs(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                addr.fullAddress,
                style: TextStyle(
                  fontSize: fs(context, 11),
                  color: AppColors.mutedText,
                ),
              ),
              trailing: state.selectedAddress?.label == addr.label
                  ? Icon(Icons.check_circle, color: AppColors.sage, size: 20)
                  : null,
              onTap: () {
                state.setAddress(addr);
                Navigator.pop(context);
              },
            ),
          ),
          const Divider(color: AppColors.line),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                size: 18,
                color: AppColors.coral,
              ),
            ),
            title: Text(
              'Add New Address',
              style: TextStyle(
                fontSize: fs(context, 13),
                fontWeight: FontWeight.w700,
                color: AppColors.coral,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AppScope(state: state, child: const AddAddressScreen()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── ADD ADDRESS SCREEN ──────────────────────────────────────────────────────

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  String _selectedLabel = 'Home';

  final List<String> _quickLabels = ['Home', 'Work', 'Hotel', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADD ADDRESS'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Label',
            style: TextStyle(
              fontSize: fs(context, 13),
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _quickLabels
                .map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedLabel = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedLabel == label
                              ? AppColors.sage
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedLabel == label
                                ? AppColors.sage
                                : AppColors.line,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: fs(context, 12),
                            fontWeight: FontWeight.w700,
                            color: _selectedLabel == label
                                ? Colors.white
                                : AppColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Full Address',
            style: TextStyle(
              fontSize: fs(context, 13),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _InputField(
            hint: 'e.g. Plot 14, Bukoto Street, Kampala',
            controller: _addressCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Delivery Instructions (optional)',
            style: TextStyle(
              fontSize: fs(context, 13),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _InputField(
            hint: 'e.g. Call when you arrive, Gate code: 1234',
            controller: _instructionsCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: call ApiService.saveAddress()
              final addr = DeliveryAddress(
                label: _selectedLabel,
                fullAddress: _addressCtrl.text.isEmpty
                    ? 'Not specified'
                    : _addressCtrl.text,
                instructions: _instructionsCtrl.text.isEmpty
                    ? null
                    : _instructionsCtrl.text,
              );
              AppScope.of(context).setAddress(addr);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Address saved!')));
            },
            child: const Text('Save Address'),
          ),
        ],
      ),
    );
  }
}

// ─── CHECKOUT SCREEN ─────────────────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'Mobile Money';
  final List<String> _paymentMethods = [
    'Mobile Money',
    'Cash on Delivery',
    'Card',
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CHECKOUT'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Delivery Address
          _SectionHeader(title: 'Delivery Address'),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  AppScope(state: state, child: const AddressPickerSheet()),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.sage,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: state.selectedAddress == null
                        ? Text(
                            'Tap to add address',
                            style: TextStyle(
                              fontSize: fs(context, 13),
                              color: AppColors.mutedText,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.selectedAddress!.label,
                                style: TextStyle(
                                  fontSize: fs(context, 13),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                state.selectedAddress!.fullAddress,
                                style: TextStyle(
                                  fontSize: fs(context, 12),
                                  color: AppColors.mutedText,
                                ),
                              ),
                              if (state.selectedAddress!.instructions != null)
                                Text(
                                  '📝 ${state.selectedAddress!.instructions}',
                                  style: TextStyle(
                                    fontSize: fs(context, 11),
                                    color: AppColors.grayText,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.mutedText,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Order Summary'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                ...state.cart.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${item.qty}×',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(fontSize: fs(context, 13)),
                          ),
                        ),
                        Text(
                          'UGX ${MenuItem._fmt(item.total)}',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: AppColors.line, height: 1),
                if (state.promoDiscountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Discount (${state.promoCodeApplied})',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: Colors.green.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '- UGX ${MenuItem._fmt(state.promoDiscountAmount)}',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: fs(context, 14),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'UGX ${MenuItem._fmt(state.cartTotal)}',
                        style: TextStyle(
                          fontSize: fs(context, 14),
                          fontWeight: FontWeight.w900,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Payment Method'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPayment == method;
                return InkWell(
                  onTap: () => setState(() => _selectedPayment = method),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          method == 'Mobile Money'
                              ? Icons.phone_android
                              : method == 'Cash on Delivery'
                              ? Icons.payments_outlined
                              : Icons.credit_card_outlined,
                          size: 20,
                          color: isSelected
                              ? AppColors.sage
                              : AppColors.mutedText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            method,
                            style: TextStyle(
                              fontSize: fs(context, 13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.sage
                                  : AppColors.line,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.sage,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: ElevatedButton(
          onPressed: state.cart.isEmpty
              ? null
              : () {
                  state.placeOrder(); // TODO: wire to ApiService.placeOrder()
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: state,
                        child: OrderConfirmationScreen(
                          orderId: state.orders.first.id,
                        ),
                      ),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sage,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Place Order • UGX ${MenuItem._fmt(state.cartTotal)}',
            style: TextStyle(
              fontSize: fs(context, 14),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fs(context, 12),
          fontWeight: FontWeight.w700,
          color: AppColors.mutedText,
          letterSpacing: 0.08,
        ),
      ),
    );
  }
}

// ─── ORDER CONFIRMATION SCREEN ────────────────────────────────────────────────

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.sage,
                  size: 48,
                ),
              ).let((it) => Center(child: it)),
              const SizedBox(height: 24),
              Text(
                'Order Placed! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fs(context, 26),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order has been received.\nWe\'re getting it ready for you!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fs(context, 14),
                  color: AppColors.mutedText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  orderId,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                    letterSpacing: 0.05,
                  ),
                ),
              ).let(
                (it) => Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: it,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: AppScope.of(context),
                        child: OrderTrackingScreen(orderId: orderId),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delivery_dining, size: 18),
                label: const Text('Track Your Order'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const HomeShell(),
                    ),
                  ),
                  (r) => false,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: AppColors.sage),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontWeight: FontWeight.w700,
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

extension _LetExt<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}

// ─── ORDER TRACKING SCREEN ───────────────────────────────────────────────────

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final order = state.orders.where((o) => o.id == orderId).firstOrNull;

    // TODO: use GET /api/orders/{id}/track for real-time status updates (polling or WebSocket)
    final steps = [
      _TrackStep(
        label: 'Order Placed',
        icon: Icons.receipt_long_outlined,
        done: true,
      ),
      _TrackStep(
        label: 'Confirmed',
        icon: Icons.check_circle_outline,
        done:
            order != null && order.status.index >= OrderStatus.confirmed.index,
      ),
      _TrackStep(
        label: 'Being Prepared',
        icon: Icons.outdoor_grill_outlined,
        done:
            order != null && order.status.index >= OrderStatus.preparing.index,
      ),
      _TrackStep(
        label: 'On the Way',
        icon: Icons.delivery_dining_outlined,
        done: order != null && order.status.index >= OrderStatus.onTheWay.index,
      ),
      _TrackStep(
        label: 'Delivered',
        icon: Icons.done_all,
        done: order != null && order.status == OrderStatus.delivered,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRACK ORDER'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order ID card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID',
                  style: TextStyle(
                    fontSize: fs(context, 11),
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orderId,
                  style: TextStyle(
                    fontSize: fs(context, 13),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.04,
                  ),
                ),
                if (order != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'} • UGX ${MenuItem._fmt(order.total)}',
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Order Status',
            style: TextStyle(
              fontSize: fs(context, 14),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),

          // Tracking timeline
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: step.done
                            ? AppColors.sage
                            : AppColors.placeholder,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: step.done ? Colors.white : AppColors.mutedText,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: step.done ? AppColors.sage : AppColors.line,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      fontWeight: step.done ? FontWeight.w700 : FontWeight.w400,
                      color: step.done
                          ? AppColors.textDark
                          : AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 24),
          Text(
            '⚡ Live tracking will be available once your order is confirmed.',
            style: TextStyle(
              fontSize: fs(context, 12),
              color: AppColors.mutedText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackStep {
  const _TrackStep({
    required this.label,
    required this.icon,
    required this.done,
  });
  final String label;
  final IconData icon;
  final bool done;
}

// ─── ORDER HISTORY SCREEN ────────────────────────────────────────────────────

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = AppScope.of(context).orders;
    // TODO: load from ApiService.getOrderHistory() and populate orders

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORDER HISTORY'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: AppColors.line,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: fs(context, 15),
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your order history will appear here',
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final order = orders[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: AppScope.of(context),
                        child: OrderTrackingScreen(orderId: order.id),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              order.statusIcon,
                              size: 18,
                              color: AppColors.sage,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.statusLabel,
                              style: TextStyle(
                                fontSize: fs(context, 13),
                                fontWeight: FontWeight.w700,
                                color: AppColors.sage,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}',
                              style: TextStyle(
                                fontSize: fs(context, 11),
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.id,
                          style: TextStyle(
                            fontSize: fs(context, 11),
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${order.items.length} item${order.items.length == 1 ? '' : 's'} • UGX ${MenuItem._fmt(order.total)}',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AppScope(
                                      state: AppScope.of(context),
                                      child: OrderTrackingScreen(
                                        orderId: order.id,
                                      ),
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  side: const BorderSide(color: AppColors.sage),
                                ),
                                child: Text(
                                  'Track',
                                  style: TextStyle(
                                    fontSize: fs(context, 12),
                                    color: AppColors.sage,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  for (final item in order.items) {
                                    AppScope.of(context).addToCart(
                                      MenuItem(
                                        name: item.name,
                                        price: item.price,
                                      ),
                                    );
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Items added to cart!'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Reorder',
                                  style: TextStyle(
                                    fontSize: fs(context, 12),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─── NOTIFICATIONS SCREEN ────────────────────────────────────────────────────

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // TODO: load from ApiService.getNotifications()
  static const List<_NotifItem> _items = [
    _NotifItem(
      icon: Icons.local_offer_outlined,
      title: 'Special Offer! 🎉',
      body: 'Get 20% off your next order with code WELCOME20',
      time: '2 min ago',
      unread: true,
    ),
    _NotifItem(
      icon: Icons.delivery_dining_outlined,
      title: 'Order on the way',
      body: 'Your order ORD-123 is out for delivery!',
      time: '1 hr ago',
      unread: true,
    ),
    _NotifItem(
      icon: Icons.workspace_premium_outlined,
      title: 'You earned 50 points!',
      body: 'Keep ordering to unlock your next reward.',
      time: 'Yesterday',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {}, // TODO: mark all read via ApiService
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: AppColors.line,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: fs(context, 15),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.line, height: 1),
              itemBuilder: (_, i) {
                final notif = _items[i];
                return Container(
                  color: notif.unread
                      ? AppColors.sage.withValues(alpha: 0.04)
                      : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: notif.unread
                            ? AppColors.sage.withValues(alpha: 0.12)
                            : AppColors.placeholder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        notif.icon,
                        size: 20,
                        color: notif.unread
                            ? AppColors.sage
                            : AppColors.mutedText,
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontSize: fs(context, 13),
                        fontWeight: notif.unread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif.body,
                          style: TextStyle(
                            fontSize: fs(context, 12),
                            color: AppColors.grayText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notif.time,
                          style: TextStyle(
                            fontSize: fs(context, 10),
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    trailing: notif.unread
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}

class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
  });
  final IconData icon;
  final String title, body, time;
  final bool unread;
}

// ─── SEARCH SCREEN ───────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<MenuItem> _results = [];
  bool _searched = false;

  void _search(String query) {
    // TODO: replace with ApiService.searchMenu(query: query) for backend search
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final matches = allMenuItems
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
    setState(() {
      _results = matches;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SEARCH MENU'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _InputField(
              hint: 'Search burgers, pizza, tea…',
              controller: _ctrl,
              onChanged: _search,
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.mutedText,
              ),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.mutedText,
                      ),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
          ),
          if (!_searched)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 56, color: AppColors.line),
                    const SizedBox(height: 12),
                    Text(
                      'Search our menu',
                      style: TextStyle(
                        fontSize: fs(context, 14),
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_food_outlined,
                      size: 56,
                      color: AppColors.line,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No results for "${_ctrl.text}"',
                      style: TextStyle(
                        fontSize: fs(context, 14),
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _SearchResultTile(item: _results[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.imagePath != null
                  ? Image.asset(item.imagePath!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.placeholder,
                      child: Icon(
                        Icons.fastfood_outlined,
                        size: 28,
                        color: AppColors.sage.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: fs(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.note == 'from'
                      ? 'from ${item.priceFormatted}'
                      : item.priceFormatted,
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: AppColors.sage,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              state.addToCart(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} added to cart'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.sage,
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAVOURITES SCREEN ───────────────────────────────────────────────────────

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final favItems = allMenuItems
        .where((item) => state.isFavorite(item.name))
        .toList();
    // TODO: merge with ApiService.getFavorites() once backend is ready

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAVOURITES'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: favItems.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 56, color: AppColors.line),
                  const SizedBox(height: 12),
                  Text(
                    'No favourites yet',
                    style: TextStyle(
                      fontSize: fs(context, 15),
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap ♥ on any item to save it here',
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: favItems.length,
              itemBuilder: (_, i) => _MenuItemGridCard(item: favItems[i]),
            ),
    );
  }
}

// ─── DEALS SCREEN ────────────────────────────────────────────────────────────

class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

  // TODO: load from ApiService.getDeals() / promo endpoint
  static const List<_Deal> _deals = [
    _Deal(
      title: '10% Off Your Order',
      code: 'OWEITU10',
      description: 'Use code at checkout to get 10% off your total order.',
      icon: Icons.local_offer_outlined,
      color: Color(0xFFE8F5E9),
      accentColor: Colors.green,
      expiry: 'Expires 31 Dec 2026',
    ),
    _Deal(
      title: '20% Welcome Discount',
      code: 'WELCOME20',
      description: 'New customers get 20% off their first order.',
      icon: Icons.celebration_outlined,
      color: Color(0xFFFFF8E1),
      accentColor: Color(0xFFF5A623),
      expiry: 'For new users only',
    ),
    _Deal(
      title: 'Free Drink with Pizza',
      code: null,
      description:
          'Order any pizza and get a free drink. Auto-applied at checkout.',
      icon: Icons.local_drink_outlined,
      color: Color(0xFFE8EAF6),
      accentColor: AppColors.sage,
      expiry: 'Weekends only',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEALS'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _deals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) {
          final deal = _deals[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: deal.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: deal.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(deal.icon, color: deal.accentColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        deal.title,
                        style: TextStyle(
                          fontSize: fs(context, 15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  deal.description,
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: AppColors.grayText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (deal.code != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: deal.accentColor.withValues(alpha: 0.5),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Text(
                          deal.code!,
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                            color: deal.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code ${deal.code} copied!'),
                              backgroundColor: AppColors.sage,
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 18,
                          color: deal.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  deal.expiry,
                  style: TextStyle(
                    fontSize: fs(context, 10),
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Deal {
  const _Deal({
    required this.title,
    this.code,
    required this.description,
    required this.icon,
    required this.color,
    required this.accentColor,
    required this.expiry,
  });
  final String title;
  final String? code;
  final String description;
  final IconData icon;
  final Color color;
  final Color accentColor;
  final String expiry;
}

// ─── E-GIFT CARD SCREEN ──────────────────────────────────────────────────────

class EGiftCardScreen extends StatefulWidget {
  const EGiftCardScreen({super.key});

  @override
  State<EGiftCardScreen> createState() => _EGiftCardScreenState();
}

class _EGiftCardScreenState extends State<EGiftCardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-GIFT CARD'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF5F5F5),
            child: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.mutedText,
              indicator: BoxDecoration(color: AppColors.sage),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'SEND A GIFT'),
                Tab(text: 'REDEEM'),
              ],
            ),
          ),
          Expanded(child: _tabs.index == 0 ? _SendGiftTab() : _RedeemGiftTab()),
        ],
      ),
    );
  }
}

class _SendGiftTab extends StatelessWidget {
  static const List<int> _amounts = [10000, 20000, 50000, 100000];
  int _selected = 20000;

  _SendGiftTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.sage, AppColors.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Oweitu Cafe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fs(context, 16),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'E-Gift Card',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: fs(context, 11),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'UGX ${MenuItem._fmt(_selected)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fs(context, 22),
                              fontWeight: FontWeight.w900,
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
          const SizedBox(height: 20),
          Text(
            'Select Amount',
            style: TextStyle(
              fontSize: fs(context, 13),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _amounts
                .map(
                  (amt) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = amt),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: amt != _amounts.last ? 8 : 0,
                        ),
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selected == amt
                              ? AppColors.sage
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selected == amt
                                ? AppColors.sage
                                : AppColors.line,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${(amt / 1000).toInt()}K',
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              fontWeight: FontWeight.w700,
                              color: _selected == amt
                                  ? Colors.white
                                  : AppColors.mutedText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const _InputField(hint: "Recipient's name"),
          const SizedBox(height: 10),
          const _InputField(
            hint: "Recipient's phone number",
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          const _InputField(hint: 'Personal message (optional)', maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // TODO: call ApiService.sendGiftCard()
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gift card sent successfully! 🎁'),
                  backgroundColor: AppColors.sage,
                ),
              );
            },
            child: Text('Send Gift Card • UGX ${MenuItem._fmt(_selected)}'),
          ),
        ],
      ),
    );
  }
}

class _RedeemGiftTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.card_giftcard, size: 56, color: AppColors.sage),
          const SizedBox(height: 16),
          Text(
            'Redeem a Gift Card',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fs(context, 18),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the gift card code you received to add credit to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fs(context, 13),
              color: AppColors.mutedText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const _InputField(hint: 'Gift card code (e.g. OWGFT-XXXX-XXXX)'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: call ApiService.redeemGiftCard()
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Gift card redeemed! Credit added to your account.',
                  ),
                  backgroundColor: AppColors.sage,
                ),
              );
            },
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }
}

// ─── SETTINGS SCREEN ─────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotifs = true;
  bool _promoNotifs = true;
  bool _emailUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _SettingsSection(
            title: 'NOTIFICATIONS',
            children: [
              _SwitchRow(
                label: 'Order updates',
                value: _orderNotifs,
                onChanged: (v) => setState(() => _orderNotifs = v),
              ),
              _SwitchRow(
                label: 'Promo & deals',
                value: _promoNotifs,
                onChanged: (v) => setState(() => _promoNotifs = v),
              ),
              _SwitchRow(
                label: 'Email newsletters',
                value: _emailUpdates,
                onChanged: (v) => setState(() => _emailUpdates = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'ACCOUNT',
            children: [
              _NavRow(label: 'Change Password', onTap: () {}),
              _NavRow(
                label: 'Manage Addresses',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const AddAddressScreen(),
                    ),
                  ),
                ),
              ),
              _NavRow(label: 'Payment Methods', onTap: () {}),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'SUPPORT',
            children: [
              _NavRow(
                label: 'Contact Support',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                ),
              ),
              _NavRow(label: 'FAQs', onTap: () {}),
              _NavRow(label: 'Rate the App', onTap: () {}),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'LEGAL',
            children: [
              _NavRow(
                label: 'Terms & Conditions',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _SimpleInfoScreen(
                      title: 'TERMS & CONDITIONS',
                      body: _kTermsText,
                    ),
                  ),
                ),
              ),
              _NavRow(
                label: 'Privacy Policy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _SimpleInfoScreen(
                      title: 'PRIVACY POLICY',
                      body: _kPrivacyText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Oweitu Cafe App v1.3.3\nBuilt with ❤️ in Uganda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs(context, 11),
                color: AppColors.mutedText,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: fs(context, 11),
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              letterSpacing: 0.08,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fs(context, 13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.sage,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fs(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CONTACT SUPPORT SCREEN ───────────────────────────────────────────────────

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTACT SUPPORT'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _submitted ? _submittedView() : _formView(),
    );
  }

  Widget _formView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Contact options
        _ContactOptionCard(
          icon: Icons.chat_outlined,
          label: 'Live Chat',
          subtitle: 'Chat with us now',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        _ContactOptionCard(
          icon: Icons.phone_outlined,
          label: 'Call Us',
          subtitle: '+256 XXX XXX XXX',
          onTap: () {},
        ),
        const SizedBox(height: 10),
        _ContactOptionCard(
          icon: Icons.email_outlined,
          label: 'Email',
          subtitle: 'support@oweitu.com',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Text(
          'Send a Message',
          style: TextStyle(
            fontSize: fs(context, 14),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const _InputField(hint: 'Subject'),
        const SizedBox(height: 10),
        const _InputField(hint: 'Describe your issue...', maxLines: 5),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _submitted = true),
          child: const Text('Send Message'),
        ),
      ],
    );
  }

  Widget _submittedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: AppColors.sage),
            const SizedBox(height: 16),
            Text(
              'Message Sent!',
              style: TextStyle(
                fontSize: fs(context, 20),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ve received your message and will respond within 24 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs(context, 13),
                color: AppColors.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactOptionCard extends StatelessWidget {
  const _ContactOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.sage),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ABOUT US / GALLERY / TERMS / PRIVACY ────────────────────────────────────

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABOUT US'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Logo / hero area
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.sage, AppColors.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Oweitu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fs(context, 32),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'CAFÉ & RESTAURANT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: fs(context, 10),
                      letterSpacing: 0.12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Our Story',
            style: TextStyle(
              fontSize: fs(context, 16),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // TODO: load from backend CMS / ApiService.getAbout()
            'Oweitu Cafe is a homegrown café & restaurant based in Kampala, Uganda. We believe great food should be accessible, affordable, and always freshly prepared.\n\nFrom our beloved chapati and katogo breakfasts to freshly baked pizzas and crispy fried chicken, every dish is made with care and quality ingredients.',
            style: TextStyle(
              fontSize: fs(context, 13),
              color: AppColors.grayText,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Find Us',
            style: TextStyle(
              fontSize: fs(context, 16),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // TODO: load branches from ApiService.getBranches()
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: 'Kampala, Uganda (multiple branches)',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.schedule_outlined,
            text: 'Mon–Sun: 7:00 AM – 10:00 PM',
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.phone_outlined, text: '+256 XXX XXX XXX'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.email_outlined, text: 'hello@oweitu.com'),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.language_outlined, text: 'www.oweitu.com'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.sage),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fs(context, 13),
              color: AppColors.grayText,
            ),
          ),
        ),
      ],
    );
  }
}

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static const List<String> _imagePaths = [
    'assets/images/Chicken Burger.jpg',
    'assets/images/Beef Burger.jpg',
    'assets/images/ChickenTikka.jpg',
    'assets/images/Chicken BBq.jpg',
    'assets/images/Vegetable Pizza.jpg',
    'assets/images/Margherita Pizza.jpg',
    'assets/images/African Tea.jpg',
    'assets/images/Hot Chocolate.jpg',
    'assets/images/Minute Maid.jpg',
    'assets/images/Tea Masala.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GALLERY'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _imagePaths.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _showFullscreen(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(_imagePaths[i], fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: _imagePaths.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(child: Image.asset(_imagePaths[i])),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleInfoScreen extends StatelessWidget {
  const _SimpleInfoScreen({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            body,
            style: TextStyle(
              fontSize: fs(context, 13),
              color: AppColors.grayText,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

const _kTermsText = '''
Terms & Conditions

Last updated: June 2026

By using the Oweitu Cafe app, you agree to these terms.

1. USE OF SERVICE
You must be at least 18 years old to use this service. You are responsible for maintaining the confidentiality of your account.

2. ORDERS & PAYMENTS
All orders are subject to availability. Prices are in Ugandan Shillings (UGX) and are inclusive of applicable taxes. We reserve the right to cancel orders in cases of pricing errors or unavailability.

3. DELIVERY
Estimated delivery times are guidelines only. Oweitu Cafe is not liable for delays caused by traffic, weather, or other factors beyond our control.

4. REFUNDS & CANCELLATIONS
Cancellations must be made within 5 minutes of placing an order. Refunds for valid claims will be processed within 3-5 business days.

5. MODIFICATIONS
We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of the revised terms.

Contact us at support@oweitu.com for any questions.
''';

const _kPrivacyText = '''
Privacy Policy

Last updated: June 2026

Oweitu Cafe values your privacy.

1. INFORMATION WE COLLECT
We collect your name, email/phone, delivery addresses, and order history to provide our service.

2. HOW WE USE YOUR DATA
Your data is used to process orders, personalise your experience, send relevant notifications, and improve our service.

3. DATA SHARING
We do not sell your personal data. We may share limited data with delivery partners and payment processors solely to fulfil your orders.

4. DATA SECURITY
We use industry-standard encryption to protect your data. However, no method of transmission over the internet is 100% secure.

5. YOUR RIGHTS
You may request access to, correction of, or deletion of your personal data at any time by contacting support@oweitu.com.

6. COOKIES
Our app may use analytics tools that collect anonymised usage data to help us improve the app experience.
''';

// ─── ITEM DETAIL SHEET ───────────────────────────────────────────────────────

class MenuItemDetailSheet extends StatefulWidget {
  const MenuItemDetailSheet({super.key, required this.item});
  final MenuItem item;

  @override
  State<MenuItemDetailSheet> createState() => _MenuItemDetailSheetState();
}

class _MenuItemDetailSheetState extends State<MenuItemDetailSheet> {
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isFav = state.isFavorite(widget.item.name);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: widget.item.imagePath != null
                  ? Image.asset(widget.item.imagePath!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.placeholder,
                      child: Icon(
                        Icons.fastfood_outlined,
                        size: 60,
                        color: AppColors.sage.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: TextStyle(
                          fontSize: fs(context, 16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => state.toggleFavorite(widget.item.name),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppColors.coral : AppColors.mutedText,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.priceFormatted,
                  style: TextStyle(
                    fontSize: fs(context, 15),
                    fontWeight: FontWeight.w800,
                    color: AppColors.sage,
                  ),
                ),
                if (widget.item.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description!,
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      color: AppColors.grayText,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Special instructions',
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 6),
                _InputField(
                  hint: 'e.g. No onions, extra sauce…',
                  controller: _noteCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Qty selector
                    _QtyBtn(
                      icon: Icons.remove,
                      onTap: () {
                        if (_qty > 1) setState(() => _qty--);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_qty',
                        style: TextStyle(
                          fontSize: fs(context, 16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _QtyBtn(
                      icon: Icons.add,
                      onTap: () => setState(() => _qty++),
                    ),
                    const Spacer(),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: () {
                          for (int i = 0; i < _qty; i++) {
                            state.addToCart(
                              widget.item,
                              note: _noteCtrl.text.trim().isEmpty
                                  ? null
                                  : _noteCtrl.text.trim(),
                            );
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added $_qty × ${widget.item.name}',
                              ),
                              backgroundColor: AppColors.sage,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Add • UGX ${MenuItem._fmt(widget.item.price * _qty)}',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HOME ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onStartOrder});
  final VoidCallback onStartOrder;

  @override
  Widget build(BuildContext context) {
    final orders = AppScope.of(context).orders;
    final sw = MediaQuery.of(context).size.width;

    return ListView(
      children: [
        SizedBox(
          height: sw * 0.6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/Hero.jpg', fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.3)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WELCOME TO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fs(context, 11),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oweitu Cafe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fs(context, 40),
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Café & Restaurant',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: fs(context, 12),
                        letterSpacing: 0.06,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        minimumSize: Size.zero,
                        textStyle: TextStyle(
                          fontSize: fs(context, 13),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.04,
                        ),
                      ),
                      onPressed: onStartOrder,
                      icon: const Icon(Icons.restaurant_menu, size: 18),
                      label: const Text('View Menu'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search bar shortcut
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AppScope(
                  state: AppScope.of(context),
                  child: const SearchScreen(),
                ),
              ),
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: AppColors.mutedText),
                  const SizedBox(width: 8),
                  Text(
                    'Search menu…',
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'POPULAR PICKS',
            style: TextStyle(
              fontSize: fs(context, 11),
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
              letterSpacing: 0.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: const [
              _QuickPickChip(
                label: 'Chips & Chicken',
                price: 'UGX 17,000',
                icon: Icons.lunch_dining,
              ),
              _QuickPickChip(
                label: 'Chicken Tikka Pizza',
                price: 'from UGX 25,000',
                icon: Icons.local_pizza,
              ),
              _QuickPickChip(
                label: 'African Tea',
                price: 'UGX 4,000',
                icon: Icons.local_cafe,
              ),
              _QuickPickChip(
                label: 'Chicken Burger',
                price: 'UGX 13,000',
                icon: Icons.lunch_dining_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FIND US',
                style: TextStyle(
                  fontSize: fs(context, 11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.public, size: 16),
                label: const Text('View Oweitu Cafe Branches'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECENT ORDERS',
                style: TextStyle(
                  fontSize: fs(context, 11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 10),
              if (orders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'No orders placed recently',
                    style: TextStyle(
                      fontSize: fs(context, 13),
                      color: AppColors.mutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Column(
                  children: orders
                      .take(2)
                      .map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AppScope(
                                  state: AppScope.of(context),
                                  child: OrderTrackingScreen(orderId: order.id),
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    order.statusIcon,
                                    size: 20,
                                    color: AppColors.sage,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.statusLabel,
                                          style: TextStyle(
                                            fontSize: fs(context, 13),
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.sage,
                                          ),
                                        ),
                                        Text(
                                          '${order.items.length} items • UGX ${MenuItem._fmt(order.total)}',
                                          style: TextStyle(
                                            fontSize: fs(context, 11),
                                            color: AppColors.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: AppColors.mutedText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({
    required this.label,
    required this.price,
    required this.icon,
  });
  final String label, price;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.sage),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: fs(context, 11),
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: TextStyle(
              fontSize: fs(context, 10),
              color: AppColors.sage,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MENU SCREEN (Premium Image-Grid Layout) ─────────────────────────────────

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Oweitu!!',
                    style: TextStyle(
                      fontSize: fs(context, 15),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'What are you having today?',
                    style: TextStyle(
                      fontSize: fs(context, 12),
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search shortcut on menu page
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppScope(
                          state: AppScope.of(context),
                          child: const SearchScreen(),
                        ),
                      ),
                    ),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Search menu…',
                            style: TextStyle(
                              fontSize: fs(context, 13),
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final cat = menuCategories[index];
                return _MenuCategoryCard(
                  category: cat,
                  index: index,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppScope(
                          state: AppScope.of(context),
                          child: MenuItemsScreen(categoryIndex: index),
                        ),
                      ),
                    );
                  },
                );
              }, childCount: menuCategories.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCategoryCard extends StatelessWidget {
  const _MenuCategoryCard({
    required this.category,
    required this.index,
    required this.onTap,
  });
  final MenuCategoryDef category;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(category.imagePath, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.label,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: fs(context, 12),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1.25,
                        letterSpacing: 0.02,
                      ),
                    ),
                    Text(
                      category.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fs(context, 10),
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MENU ITEMS SCREEN ───────────────────────────────────────────────────────

class MenuItemsScreen extends StatelessWidget {
  const MenuItemsScreen({super.key, required this.categoryIndex});
  final int categoryIndex;

  @override
  Widget build(BuildContext context) {
    final cat = menuCategories[categoryIndex];
    final isPizza = categoryIndex == 5;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: Text(cat.label),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const CartSheet(),
                    ),
                  );
                },
              ),
              if (AppScope.of(context).itemCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${AppScope.of(context).itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isPizza
          ? const _PizzaItemsBody()
          : _RegularItemsBody(categoryIndex: categoryIndex),
    );
  }
}

class _RegularItemsBody extends StatelessWidget {
  const _RegularItemsBody({required this.categoryIndex});
  final int categoryIndex;

  List<MenuItem> get items {
    switch (categoryIndex) {
      case 0:
        return snacks;
      case 1:
        return breakfast;
      case 2:
        return burgers;
      case 3:
        return drinks;
      case 4:
        return teas;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) => _MenuItemGridCard(item: list[i]),
    );
  }
}

class _MenuItemGridCard extends StatelessWidget {
  const _MenuItemGridCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isFav = state.isFavorite(item.name);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AppScope(
          state: state,
          child: MenuItemDetailSheet(item: item),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imagePath == null
                        ? Container(
                            color: AppColors.placeholder,
                            child: Center(
                              child: Icon(
                                Icons.fastfood_outlined,
                                size: 40,
                                color: AppColors.sage.withValues(alpha: 0.45),
                              ),
                            ),
                          )
                        : Image.asset(item.imagePath!, fit: BoxFit.cover),
                    // Favourite button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => state.toggleFavorite(item.name),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isFav
                                ? AppColors.coral
                                : AppColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fs(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.priceFormatted,
                          style: TextStyle(
                            fontSize: fs(context, 12),
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 30,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.sage,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: TextStyle(
                                fontSize: fs(context, 11),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.05,
                              ),
                            ),
                            onPressed: () => state.addToCart(item),
                            child: const Text('ORDER'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PIZZA ITEMS BODY ────────────────────────────────────────────────────────

class _PizzaItemsBody extends StatefulWidget {
  const _PizzaItemsBody();

  @override
  State<_PizzaItemsBody> createState() => _PizzaItemsBodyState();
}

class _PizzaItemsBodyState extends State<_PizzaItemsBody> {
  final Map<String, int> _sizes = {};

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.70,
      ),
      itemCount: pizzas.length,
      itemBuilder: (context, i) {
        final pizza = pizzas[i];
        final sizeIdx = _sizes[pizza.name] ?? 0;
        final prices = [
          pizza.smallFormatted,
          pizza.mediumFormatted,
          pizza.largeFormatted,
        ];
        final rawPrices = [pizza.small, pizza.medium, pizza.large];
        const sizeLabels = ['S', 'M', 'L'];
        final state = AppScope.of(context);
        final isFav = state.isFavorite(pizza.name);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      pizza.imagePath == null
                          ? Container(
                              color: AppColors.placeholder,
                              child: Center(
                                child: Icon(
                                  Icons.local_pizza,
                                  size: 40,
                                  color: AppColors.coral.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            )
                          : Image.asset(pizza.imagePath!, fit: BoxFit.cover),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => state.toggleFavorite(pizza.name),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isFav
                                  ? AppColors.coral
                                  : AppColors.mutedText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pizza.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          height: 1.3,
                        ),
                      ),
                      Row(
                        children: List.generate(3, (s) {
                          final selected = sizeIdx == s;
                          return GestureDetector(
                            onTap: () => setState(() => _sizes[pizza.name] = s),
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              width: 26,
                              height: 22,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.sage
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.sage
                                      : AppColors.line,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  sizeLabels[s],
                                  style: TextStyle(
                                    fontSize: fs(context, 10),
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.mutedText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prices[sizeIdx],
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: double.infinity,
                            height: 28,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: TextStyle(
                                  fontSize: fs(context, 10),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.05,
                                ),
                              ),
                              onPressed: () => AppScope.of(context).addToCart(
                                MenuItem(
                                  name:
                                      '${pizza.name} (${['Small', 'Medium', 'Large'][sizeIdx]})',
                                  price: rawPrices[sizeIdx],
                                ),
                              ),
                              child: const Text('ORDER'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── REWARDS ─────────────────────────────────────────────────────────────────

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: const [
        RewardsBanner(),
        SizedBox(height: 14),
        PointsCard(),
        SizedBox(height: 14),
        HowItWorks(),
      ],
    );
  }
}

class RewardsBanner extends StatelessWidget {
  const RewardsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to',
            style: TextStyle(
              fontSize: fs(context, 13),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'Rewards',
            style: TextStyle(
              fontSize: fs(context, 28),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Introducing Rewards! Our way to say\n'Thank you' for using our app.",
            style: TextStyle(
              fontSize: fs(context, 12),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class PointsCard extends StatelessWidget {
  const PointsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: load points from ApiService.getRewardsPoints()
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_cafe, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Text(
                'Points Earned',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '80 pts',
            style: TextStyle(
              color: Colors.white,
              fontSize: fs(context, 32),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '1,000 pts needed for next reward',
            style: TextStyle(color: Colors.white54, fontSize: fs(context, 11)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: const LinearProgressIndicator(
              value: 0.08,
              minHeight: 7,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class HowItWorks extends StatelessWidget {
  const HowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Text(
              'How it works',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: fs(context, 14),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          ...rewardRows.map((row) => _RewardRow(row: row)),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.row});
  final RewardRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(row.icon, color: AppColors.navy, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: fs(context, 13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.body,
                      style: TextStyle(
                        color: AppColors.grayText,
                        fontSize: fs(context, 12),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.line),
      ],
    );
  }
}

// ─── MORE ────────────────────────────────────────────────────────────────────

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        Text(
          'Oweitu\nCafe',
          style: TextStyle(
            color: AppColors.sage,
            fontSize: fs(context, 40),
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 28),
        _MoreRow(
          text: 'E-Gift Card',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const EGiftCardScreen())),
        ),
        _MoreRow(
          text: 'Track Order',
          onTap: () {
            final orders = AppScope.of(context).orders;
            if (orders.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppScope(
                    state: AppScope.of(context),
                    child: OrderTrackingScreen(orderId: orders.first.id),
                  ),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppScope(
                    state: AppScope.of(context),
                    child: const OrderHistoryScreen(),
                  ),
                ),
              );
            }
          },
        ),
        _MoreRow(
          text: 'Deals',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DealsScreen())),
        ),
        _MoreRow(
          text: 'Terms & Conditions',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _SimpleInfoScreen(
                title: 'TERMS & CONDITIONS',
                body: _kTermsText,
              ),
            ),
          ),
        ),
        _MoreRow(
          text: 'Privacy Policy',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _SimpleInfoScreen(
                title: 'PRIVACY POLICY',
                body: _kPrivacyText,
              ),
            ),
          ),
        ),
        _MoreRow(
          text: 'About Us',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutUsScreen())),
        ),
        _MoreRow(
          text: 'Gallery',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const GalleryScreen())),
        ),
        _MoreRow(
          text: 'Contact Support',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
          ),
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: fs(context, 14),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PROFILE ─────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const ProfileAvatar(size: 110),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'AIJUKA JOSHUA',
                // TODO: load from ApiService.getProfile()
                style: TextStyle(
                  fontSize: fs(context, 20),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ProfileLine(
              icon: Icons.mail_outline,
              text: 'joshuaaijuka10@gmail.com',
            ),
            const SizedBox(height: 20),
            ProfileLine(icon: Icons.phone_android, text: '769 583 353'),
            const SizedBox(height: 36),
            Center(
              child: Text.rich(
                TextSpan(
                  text: 'Want to ',
                  children: [
                    const TextSpan(
                      text: 'change your password?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: fs(context, 14)),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: () {}, child: const Text('Edit Profile')),
            // TODO: call ApiService.updateProfile() on save
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
              onPressed: () {},
              child: const Text('Delete Account'),
            ),
            // TODO: call DELETE /api/account on confirm
          ],
        ),
      ),
    );
  }
}

// ─── DRAWER ──────────────────────────────────────────────────────────────────

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.80,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.navy,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
            const ProfileAvatar(size: 80),
            const SizedBox(height: 12),
            Text(
              'AIJUKA JOSHUA',
              style: TextStyle(
                fontSize: fs(context, 15),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'joshuaaijuka10@gmail.com',
              style: TextStyle(
                fontSize: fs(context, 12),
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.line),
            DrawerRow(
              icon: Icons.home_outlined,
              text: 'Home',
              onTap: () => Navigator.of(context).pop(),
            ),
            DrawerRow(
              icon: Icons.account_circle_outlined,
              text: 'My Account',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            DrawerRow(
              icon: Icons.notifications_none,
              text: 'Notifications',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const NotificationsScreen(),
                    ),
                  ),
                );
              },
            ),
            DrawerRow(
              icon: Icons.history,
              text: 'Order History',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const OrderHistoryScreen(),
                    ),
                  ),
                );
              },
            ),
            DrawerRow(
              icon: Icons.search,
              text: 'Search Menu',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const SearchScreen(),
                    ),
                  ),
                );
              },
            ),
            DrawerRow(
              icon: Icons.favorite_border,
              text: 'Favourites',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      state: AppScope.of(context),
                      child: const FavouritesScreen(),
                    ),
                  ),
                );
              },
            ),
            DrawerRow(
              icon: Icons.local_offer_outlined,
              text: 'Deals',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DealsScreen()));
              },
            ),
            DrawerRow(
              icon: Icons.settings_outlined,
              text: 'Settings',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            DrawerRow(
              icon: Icons.logout,
              text: 'Sign out',
              onTap: () {
                Navigator.of(context).pop();
                AppScope.of(context).signOut();
              },
            ),
            const Spacer(),
            Text(
              'App Version 1.3.3',
              style: TextStyle(
                fontSize: fs(context, 11),
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class DrawerRow extends StatelessWidget {
  const DrawerRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: fs(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOTTOM NAV ──────────────────────────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      NavItem(icon: Icons.home_outlined, label: 'HOME'),
      NavItem(icon: Icons.restaurant_menu, label: 'MENU'),
      NavItem(icon: Icons.workspace_premium_outlined, label: 'REWARDS'),
      NavItem(icon: Icons.more_horiz, label: 'MORE'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? Colors.black : AppColors.sage,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? Colors.black : AppColors.sage,
                          fontSize: fs(context, 9),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    required this.label,
    this.radius = 12,
    this.icon = Icons.image_outlined,
    this.iconSize = 36,
  });
  final String label;
  final double radius;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.placeholder,
          border: Border.all(color: AppColors.placeholderBorder),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.sage, size: iconSize),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: fs(context, 11),
                    fontWeight: FontWeight.w700,
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

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.avatarFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.sage, width: size * 0.04),
          ),
          child: Icon(
            Icons.person_outline,
            size: size * 0.50,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class ProfileLine extends StatelessWidget {
  const ProfileLine({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.sage),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fs(context, 14),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── DATA MODELS ─────────────────────────────────────────────────────────────

class NavItem {
  const NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class MenuCategory {
  const MenuCategory({
    required this.title,
    required this.imageLabel,
    required this.icon,
  });
  final String title, imageLabel;
  final IconData icon;
}

class RewardRow {
  const RewardRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
}

// ─── COLORS ──────────────────────────────────────────────────────────────────

class AppColors {
  static const sage = Color(0xFF060638);
  static const coral = Color(0xFFE60000);
  static const gold = Color(0xFFFFD21A);
  static const navy = Color(0xFF020229);
  static const mutedText = Color(0xFF4F5572);
  static const grayText = Color(0xFF6D728A);
  static const textDark = Color(0xFF020229);
  static const line = Color(0xFFDDE4F0);
  static const lightPanel = Color(0xFFF2F6FC);
  static const placeholder = Color(0xFFEAF0F8);
  static const placeholderBorder = Color(0xFFD6DEEC);
  static const avatarFill = Color(0xFFE8EEF8);
}

// ─── STATIC DATA ─────────────────────────────────────────────────────────────

const rewardRows = [
  RewardRow(
    icon: Icons.paid_outlined,
    title: 'Earn Points',
    body: 'You can earn points on every order you place.',
  ),
  RewardRow(
    icon: Icons.airplanemode_active,
    title: 'Validity of Points',
    body: 'Points credited expire 1 year from the date they are credited.',
  ),
  RewardRow(
    icon: Icons.move_up_outlined,
    title: 'Points Transfer',
    body: 'Earned reward points cannot be transferred to any third party.',
  ),
];

const moreItems = [
  'E-Gift Card',
  'Track Order',
  'Deals',
  'Terms & Conditions',
  'Privacy Policy',
  'About Us',
  'Gallery',
  'Contact Support',
];
