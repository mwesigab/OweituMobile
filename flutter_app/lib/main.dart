import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
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
  void initState() {
    super.initState();
    state.loadPersistentData();
    state.initConnectivity();
  }

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

class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  final List<Order> orders = [];
  final List<CartItem> cart = [];
  final Set<String> favorites = {};
  final List<AppNotification> notifications = [
    const AppNotification(
      icon: Icons.local_offer_outlined,
      title: 'Special Offer!',
      body: 'Get 20% off your next order with code WELCOME20',
      time: '2 min ago',
      unread: true,
    ),
    const AppNotification(
      icon: Icons.delivery_dining_outlined,
      title: 'Order on the way',
      body: 'Your order ORD-123 is out for delivery!',
      time: '1 hr ago',
      unread: true,
    ),
    const AppNotification(
      icon: Icons.workspace_premium_outlined,
      title: 'You earned 50 points!',
      body: 'Keep ordering to unlock your next reward.',
      time: 'Yesterday',
      unread: false,
    ),
  ];
  DeliveryAddress? selectedAddress;
  String? promoCodeApplied;
  int promoDiscountAmount = 0;
  String deliveryType = 'Delivery';
  String profileName = 'AIJUKA JOSHUA';
  String profileEmail = 'joshuaaijuka10@gmail.com';
  String profilePhone = '769 583 353';
  bool isOffline = false;
  bool isLoading = false;
  String? profileImagePath;
  bool darkMode = false;
  String selectedLanguage = 'English';
  double deliveryFee = 0;
  double taxRate = 0.08;
  int loyaltyPoints = 80;
  List<String> searchHistory = [];
  String? appliedFilter;
  String? sortOption;
  bool isBiometricEnabled = false;
  Timer? _sessionTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  List<Map<String, dynamic>> _offlineActions = [];

  int get itemCount => cart.length;
  int get cartSubtotal => cart.fold(0, (sum, i) => sum + i.total);
  double get cartTax => cartSubtotal * taxRate;
  double get cartTotal =>
      (cartSubtotal - promoDiscountAmount + deliveryFee + cartTax).clamp(
        0,
        999999999,
      );
  bool get isDeliveryValid =>
      deliveryType == 'Takeaway' || cartSubtotal >= 10000;
  int get unreadNotificationCount =>
      notifications.where((notification) => notification.unread).length;
  String get formattedDeliveryFee => 'UGX ${_fmt(deliveryFee.round())}';
  String get formattedTax => 'UGX ${_fmt(cartTax.round())}';
  String get formattedTotal => 'UGX ${_fmt(cartTotal.round())}';

  static String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  void initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isConnected = result != ConnectivityResult.none;
      if (isOffline != !isConnected) {
        isOffline = !isConnected;
        notifyListeners();
        if (!isOffline) {
          _syncOfflineActions();
        }
      }
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    isOffline = result == ConnectivityResult.none;
    notifyListeners();
  }

  void _syncOfflineActions() {
    if (_offlineActions.isNotEmpty) {
      for (final action in _offlineActions) {
        if (action['type'] == 'add_to_cart') {
          addToCart(MenuItem(name: action['name'], price: action['price']));
        }
      }
      _offlineActions.clear();
    }
  }

  Future<void> loadPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      darkMode = prefs.getBool('darkMode') ?? false;
      selectedLanguage = prefs.getString('language') ?? 'English';
      isBiometricEnabled = prefs.getBool('biometric') ?? false;

      final savedCart = prefs.getStringList('cartItems');
      if (savedCart != null) {
        for (final itemJson in savedCart) {
          final parts = itemJson.split('|||');
          if (parts.length >= 3) {
            cart.add(
              CartItem(
                name: parts[0],
                price: int.tryParse(parts[1]) ?? 0,
                qty: int.tryParse(parts[2]) ?? 1,
                note: parts.length > 3 ? parts[3] : null,
              ),
            );
          }
        }
      }

      final savedFavs = prefs.getStringList('favorites');
      if (savedFavs != null) {
        favorites.addAll(savedFavs);
      }

      final savedAddress = prefs.getString('selectedAddress');
      if (savedAddress != null) {
        final parts = savedAddress.split('|||');
        if (parts.length >= 2) {
          selectedAddress = DeliveryAddress(
            label: parts[0],
            fullAddress: parts[1],
            instructions: parts.length > 2 ? parts[2] : null,
          );
        }
      }

      profileName = prefs.getString('profileName') ?? profileName;
      profileEmail = prefs.getString('profileEmail') ?? profileEmail;
      profilePhone = prefs.getString('profilePhone') ?? profilePhone;
      profileImagePath = prefs.getString('profileImagePath');

      final savedSearch = prefs.getStringList('searchHistory');
      if (savedSearch != null) {
        searchHistory = savedSearch;
      }

      loyaltyPoints = prefs.getInt('loyaltyPoints') ?? 80;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading persistent data: $e');
    }
  }

  Future<void> savePersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('darkMode', darkMode);
      await prefs.setString('language', selectedLanguage);
      await prefs.setBool('biometric', isBiometricEnabled);

      final cartList = cart.map((item) {
        return '${item.name}|||${item.price}|||${item.qty}|||${item.note ?? ''}';
      }).toList();
      await prefs.setStringList('cartItems', cartList);

      await prefs.setStringList('favorites', favorites.toList());

      if (selectedAddress != null) {
        await prefs.setString(
          'selectedAddress',
          '${selectedAddress!.label}|||${selectedAddress!.fullAddress}|||${selectedAddress!.instructions ?? ''}',
        );
      }

      await prefs.setString('profileName', profileName);
      await prefs.setString('profileEmail', profileEmail);
      await prefs.setString('profilePhone', profilePhone);
      if (profileImagePath != null) {
        await prefs.setString('profileImagePath', profileImagePath!);
      }

      await prefs.setStringList('searchHistory', searchHistory);
      await prefs.setInt('loyaltyPoints', loyaltyPoints);

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving persistent data: $e');
    }
  }

  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  void signIn() {
    isAuthenticated = true;
    savePersistentData();
    _startSessionTimer();
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
    deliveryType = 'Delivery';
    _sessionTimer?.cancel();
    savePersistentData();
    notifyListeners();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 30), () {
      signOut();
    });
  }

  void extendSession() {
    _startSessionTimer();
  }

  void addToCart(MenuItem item, {String? note}) {
    final existing = cart
        .where((c) => c.name == item.name && c.note == note)
        .toList();
    if (existing.isNotEmpty) {
      if (existing.first.qty < 99) {
        existing.first.qty++;
      }
    } else {
      cart.add(CartItem(name: item.name, price: item.price, note: note));
    }
    savePersistentData();
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    if (item.qty > 1) {
      item.qty--;
    } else {
      cart.remove(item);
    }
    savePersistentData();
    notifyListeners();
  }

  void removeFromCartWithUndo(CartItem item, BuildContext context) {
    final index = cart.indexOf(item);
    if (index == -1) return;
    cart.removeAt(index);
    savePersistentData();
    notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed from cart'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            cart.insert(index, item);
            savePersistentData();
            notifyListeners();
          },
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.sage,
      ),
    );
  }

  void clearCart() {
    cart.clear();
    promoCodeApplied = null;
    promoDiscountAmount = 0;
    savePersistentData();
    notifyListeners();
  }

  void toggleFavorite(String itemName) {
    if (favorites.contains(itemName)) {
      favorites.remove(itemName);
    } else {
      favorites.add(itemName);
    }
    savePersistentData();
    notifyListeners();
  }

  bool isFavorite(String itemName) => favorites.contains(itemName);

  void setAddress(DeliveryAddress address) {
    selectedAddress = address;
    savePersistentData();
    notifyListeners();
  }

  void setDeliveryType(String type) {
    deliveryType = type;
    if (type == 'Takeaway') {
      deliveryFee = 0;
    } else {
      deliveryFee = calculateDeliveryFee();
    }
    savePersistentData();
    notifyListeners();
  }

  double calculateDeliveryFee() {
    if (selectedAddress == null) return 5000;
    return 5000;
  }

  void markAllNotificationsRead() {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(unread: false);
    }
    notifyListeners();
  }

  bool applyPromo(String code) {
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
    final id = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final pointsEarned = (cartTotal / 1000).floor();
    loyaltyPoints += pointsEarned;

    orders.insert(
      0,
      Order(
        id: id,
        items: List.from(cart),
        total: cartTotal.round(),
        address: deliveryType == 'Takeaway'
            ? 'Takeaway'
            : (selectedAddress?.label ?? 'Not specified'),
        placedAt: DateTime.now(),
        status: OrderStatus.placed,
        deliveryType: deliveryType,
      ),
    );
    clearCart();
    savePersistentData();
    notifyListeners();
  }

  void cancelOrder(String orderId) {
    final order = orders.where((o) => o.id == orderId).firstOrNull;
    if (order != null && order.status.index <= OrderStatus.confirmed.index) {
      order.status = OrderStatus.cancelled;
      notifyListeners();
    }
  }

  void reorder(String orderId) {
    final order = orders.where((o) => o.id == orderId).firstOrNull;
    if (order != null) {
      for (final item in order.items) {
        addToCart(MenuItem(name: item.name, price: item.price));
      }
    }
  }

  void addSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    searchHistory.remove(query);
    searchHistory.insert(0, query);
    if (searchHistory.length > 10) {
      searchHistory.removeLast();
    }
    savePersistentData();
    notifyListeners();
  }

  void clearSearchHistory() {
    searchHistory.clear();
    savePersistentData();
    notifyListeners();
  }

  void setFilter(String? filter) {
    appliedFilter = filter;
    notifyListeners();
  }

  void setSortOption(String? option) {
    sortOption = option;
    notifyListeners();
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    savePersistentData();
    notifyListeners();
  }

  void setLanguage(String language) {
    selectedLanguage = language;
    savePersistentData();
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
    String? imagePath,
  }) {
    if (name != null) profileName = name;
    if (email != null) profileEmail = email;
    if (phone != null) profilePhone = phone;
    if (imagePath != null) profileImagePath = imagePath;
    savePersistentData();
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _connectivitySubscription?.cancel();
    savePersistentData();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

void requestCheckoutAuth(
  BuildContext context,
  AppState state, {
  bool closeCurrent = false,
}) {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (closeCurrent) {
    navigator.pop();
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Please sign up or log in to checkout.'),
        backgroundColor: AppColors.coral,
      ),
    );
  navigator.push(
    MaterialPageRoute(
      builder: (_) => AppScope(state: state, child: const LoginScreen()),
    ),
  );
}

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
    this.isVegetarian = false,
    this.isGlutenFree = false,
    this.isSpicy = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.available = true,
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
  final bool isVegetarian;
  final bool isGlutenFree;
  final bool isSpicy;
  final double rating;
  final int reviewCount;
  final bool available;

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
    required this.deliveryType,
    this.deliveryFee = 0,
    this.tax = 0,
    this.discount = 0,
    this.rating = 0,
    this.review = '',
  });
  final String id;
  final List<CartItem> items;
  final int total;
  final String address;
  final DateTime placedAt;
  OrderStatus status;
  final int? estimatedMinutes;
  final String deliveryType;
  final double deliveryFee;
  final double tax;
  final double discount;
  double rating;
  String review;

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

  int get elapsedMinutes => DateTime.now().difference(placedAt).inMinutes;
  String get estimatedTime {
    if (estimatedMinutes == null) return 'Calculating...';
    final remaining = estimatedMinutes! - elapsedMinutes;
    if (remaining <= 0) return 'Arriving soon';
    return '${remaining} min';
  }
}

class DeliveryAddress {
  DeliveryAddress({
    required this.label,
    required this.fullAddress,
    this.instructions,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });
  final String label;
  final String fullAddress;
  final String? instructions;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  DeliveryAddress copyWith({
    String? label,
    String? fullAddress,
    String? instructions,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryAddress(
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      instructions: instructions ?? this.instructions,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://api.oweitu.com';

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/login');
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String identifier,
    required String password,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/register');
  }

  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/social');
  }

  static Future<void> forgotPassword({required String identifier}) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/auth/forgot-password');
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/categories');
  }

  static Future<List<Map<String, dynamic>>> getMenuItems({
    String? categoryId,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/items');
  }

  static Future<List<Map<String, dynamic>>> searchMenu({
    required String query,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/search?q=$query');
  }

  static Future<List<Map<String, dynamic>>> getFeaturedItems() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/menu/featured');
  }

  static Future<Map<String, dynamic>> placeOrder({
    required List<CartItem> items,
    required String addressId,
    String? promoCode,
    String? paymentMethod,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/orders');
  }

  static Future<List<Map<String, dynamic>>> getOrderHistory() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/orders');
  }

  static Future<Map<String, dynamic>> trackOrder({
    required String orderId,
  }) async {
    throw UnimplementedError('Wire to GET $baseUrl/api/orders/$orderId/track');
  }

  static Future<List<Map<String, dynamic>>> getAddresses() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/addresses');
  }

  static Future<Map<String, dynamic>> saveAddress({
    required String label,
    required String fullAddress,
    String? instructions,
    bool isDefault = false,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/addresses');
  }

  static Future<void> deleteAddress({required String id}) async {
    throw UnimplementedError('Wire to DELETE $baseUrl/api/addresses/$id');
  }

  static Future<Map<String, dynamic>> validatePromo({
    required String code,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/promos/validate');
  }

  static Future<List<String>> getFavorites() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/favorites');
  }

  static Future<void> toggleFavorite({required String itemName}) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/favorites');
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/notifications');
  }

  static Future<void> markNotificationRead({
    required String notificationId,
  }) async {
    throw UnimplementedError(
      'Wire to POST $baseUrl/api/notifications/$notificationId/read',
    );
  }

  static Future<Map<String, dynamic>> getProfile() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/profile');
  }

  static Future<void> updateProfile({
    required Map<String, dynamic> data,
  }) async {
    throw UnimplementedError('Wire to PUT $baseUrl/api/profile');
  }

  static Future<void> submitReview({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/reviews');
  }

  static Future<List<Map<String, dynamic>>> getBranches() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/branches');
  }

  static Future<Map<String, dynamic>> getRewardsPoints() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/rewards/points');
  }

  static Future<List<Map<String, dynamic>>> getRewardsHistory() async {
    throw UnimplementedError('Wire to GET $baseUrl/api/rewards/history');
  }

  static Future<Map<String, dynamic>> initializePayment({
    required int amount,
    required String method,
    required String orderId,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/payments/initialize');
  }

  static Future<void> sendGiftCard({
    required String recipientPhone,
    required int amount,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/giftcards/send');
  }

  static Future<Map<String, dynamic>> redeemGiftCard({
    required String code,
  }) async {
    throw UnimplementedError('Wire to POST $baseUrl/api/giftcards/redeem');
  }
}

// ... rest of your code continues here (snacks, breakfast, burgers, drinks, teas, pizzas, menuCategories, LoginScreen, etc.)
const snacks = [
  MenuItem(
    name: 'Chips, 2 Pcs of Chicken and a Soda',
    price: 17000,
    imagePath: 'assets/images/Beef/2pacs of chicken and Chips.jpg',
    prepTimeMinutes: 15,
    rating: 4.5,
    reviewCount: 128,
    tags: ['Popular', 'Chicken'],
  ),
  MenuItem(
    name: 'Chips, 3 Pcs of Chicken and a Soda',
    price: 23000,
    imagePath: 'assets/images/3pacs of chicken and soda.jpg',
    prepTimeMinutes: 20,
    rating: 4.7,
    reviewCount: 95,
    tags: ['Popular', 'Chicken'],
  ),
  MenuItem(
    name: 'Chips, 4 Pcs of Chicken and a Soda',
    price: 27000,
    imagePath: 'assets/images/Beef/4pacs of chicken and Chips.jpg',
    prepTimeMinutes: 20,
    rating: 4.8,
    reviewCount: 76,
    tags: ['Chicken'],
  ),
  MenuItem(
    name: '5 Pcs Chicken, 2 Regular Chips & 2 Drinks',
    price: 35000,
    imagePath: 'assets/images/Beef/5pacs of chicken and Chips.jpg',
    prepTimeMinutes: 25,
    rating: 4.9,
    reviewCount: 52,
    tags: ['Popular', 'Family Meal'],
  ),
  MenuItem(
    name: 'Chips Liver and Drink',
    price: 14000,
    imagePath: 'assets/images/Beef/Chips and Liver.jpg',
    prepTimeMinutes: 12,
    rating: 4.3,
    reviewCount: 67,
    tags: ['Beef'],
  ),
  MenuItem(
    name: 'Chips Beef and Drink',
    price: 14000,
    imagePath: 'assets/images/Beef/Chips and Beef.jpg',
    prepTimeMinutes: 12,
    rating: 4.4,
    reviewCount: 89,
    tags: ['Beef'],
  ),
  MenuItem(
    name: 'Stewed Rice, Liver and Drink',
    price: 14000,
    imagePath: 'assets/images/Beef/Stewed Rice and Liver.jpg',
    prepTimeMinutes: 15,
    rating: 4.2,
    reviewCount: 45,
    tags: ['Beef', 'Rice'],
  ),
  MenuItem(
    name: 'Stewed Rice, Beef and Drink',
    price: 14000,
    imagePath: 'assets/images/Beef/Stewed Rice and Beef.jpg',
    prepTimeMinutes: 15,
    rating: 4.5,
    reviewCount: 78,
    tags: ['Beef', 'Rice'],
  ),
  MenuItem(
    name: 'Pair of Sausages, Chips and Drink',
    price: 11000,
    imagePath: 'assets/images/Beef/Pair of Sausages and Chips.jpg',
    prepTimeMinutes: 10,
    rating: 4.1,
    reviewCount: 34,
    tags: ['Sausage'],
  ),
  MenuItem(
    name: 'Whole Fish, Chips and Drink',
    price: 26000,
    imagePath: 'assets/images/Beef/Whole Fish and Chips .jpg',
    prepTimeMinutes: 25,
    rating: 4.6,
    reviewCount: 42,
    tags: ['Fish', 'Popular'],
  ),
  MenuItem(
    name: 'Chips, 1 Chap and 1 Drink',
    price: 12000,
    imagePath: 'assets/images/Beef/Chips and 1 chap.jpg',
    prepTimeMinutes: 10,
    rating: 4.0,
    reviewCount: 56,
    tags: ['Chapati'],
  ),
  MenuItem(
    name: 'Palau Beef and a Drink',
    price: 14000,
    imagePath: 'assets/images/Beef/Pilawo and Beef.jpg',
    prepTimeMinutes: 18,
    rating: 4.4,
    reviewCount: 63,
    tags: ['Beef', 'Rice'],
  ),
  MenuItem(
    name: 'Chicken / Beef Burger, Chips and Drink',
    price: 25000,
    imagePath: 'assets/images/Beef/Beef Burger and Chips.jpg',
    prepTimeMinutes: 15,
    rating: 4.7,
    reviewCount: 112,
    tags: ['Burger', 'Popular'],
  ),
  MenuItem(
    name: 'Chips, Goats Meat and a Drink',
    price: 17000,
    imagePath: "assets/images/Beef/Chips and Goat's meat.jpg",
    prepTimeMinutes: 20,
    rating: 4.3,
    reviewCount: 38,
    tags: ['Goat Meat'],
  ),
  MenuItem(
    name: 'Half Chips, Half Rice with Liver / Gravy / Beef',
    price: 16000,
    imagePath: 'assets/images/Beef/Rice with LIver.jpg',
    prepTimeMinutes: 15,
    rating: 4.2,
    reviewCount: 47,
    tags: ['Mixed'],
  ),
  MenuItem(
    name: 'Beef / Liver Plain',
    price: 7000,
    imagePath: 'assets/images/Beef/Liver Plain.jpg',
    prepTimeMinutes: 8,
    rating: 4.1,
    reviewCount: 29,
    tags: ['Beef'],
  ),
  MenuItem(
    name: 'Plain Chips',
    price: 7000,
    imagePath: 'assets/images/Plain Chips.jpg',
    prepTimeMinutes: 8,
    rating: 4.0,
    reviewCount: 45,
    tags: ['Vegetarian'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Fish Fillet Plain (2 Pcs)',
    price: 11000,
    imagePath: 'assets/images/Fish Fillet Plain.jpg',
    prepTimeMinutes: 12,
    rating: 4.4,
    reviewCount: 33,
    tags: ['Fish'],
  ),
  MenuItem(
    name: 'Pilawo Plain',
    price: 7000,
    imagePath: 'assets/images/Pilawo Plain.jpg',
    prepTimeMinutes: 10,
    rating: 4.2,
    reviewCount: 41,
    tags: ['Vegetarian', 'Rice'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Plain Chicken',
    price: 9000,
    imagePath: 'assets/images/Plain Chicken.jpg',
    prepTimeMinutes: 10,
    rating: 4.5,
    reviewCount: 58,
    tags: ['Chicken'],
  ),
];

const breakfast = [
  MenuItem(
    name: 'Katogo Vegetables',
    price: 6000,
    imagePath: 'assets/images/Katogo Vegetables.jpg',
    prepTimeMinutes: 10,
    rating: 4.3,
    reviewCount: 67,
    tags: ['Vegetarian', 'Breakfast'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Katogo Beef / Liver',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/ Liver.jpg',
    prepTimeMinutes: 12,
    rating: 4.6,
    reviewCount: 89,
    tags: ['Beef', 'Breakfast'],
  ),
  MenuItem(
    name: 'A Pair of Beef Samosa',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Beef Samosa.jpg',
    prepTimeMinutes: 5,
    rating: 4.2,
    reviewCount: 45,
    tags: ['Beef', 'Snack'],
  ),
  MenuItem(
    name: 'Plain Omelette',
    price: 2500,
    imagePath: 'assets/images/Katogo Beef/Plain Omelette.jpg',
    prepTimeMinutes: 5,
    rating: 4.4,
    reviewCount: 78,
    tags: ['Egg', 'Breakfast'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Spanish Omelette',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Spanish Omelette.jpg',
    prepTimeMinutes: 7,
    rating: 4.5,
    reviewCount: 56,
    tags: ['Egg', 'Breakfast'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Chapati and Beans',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Chapati and Beans.jpg',
    prepTimeMinutes: 8,
    rating: 4.3,
    reviewCount: 92,
    tags: ['Vegetarian', 'Breakfast'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Plain Chapati',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Plain Chapatti.jpg',
    prepTimeMinutes: 5,
    rating: 4.1,
    reviewCount: 67,
    tags: ['Vegetarian', 'Breakfast'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Chapati and Gravy',
    price: 3000,
    prepTimeMinutes: 6,
    rating: 4.2,
    reviewCount: 54,
    tags: ['Breakfast'],
  ),
  MenuItem(
    name: 'Kebab Plain',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Kebab Plain.jpg',
    prepTimeMinutes: 7,
    rating: 4.0,
    reviewCount: 34,
    tags: ['Snack'],
  ),
  MenuItem(
    name: 'Chaps Plain',
    price: 3000,
    imagePath: 'assets/images/Katogo Beef/Chap Plain.jpg',
    prepTimeMinutes: 5,
    rating: 4.1,
    reviewCount: 29,
    tags: ['Breakfast'],
  ),
  MenuItem(
    name: 'A Pair of Sausage Plain',
    price: 2000,
    imagePath: 'assets/images/Katogo Beef/Pair of Sausage.jpg',
    prepTimeMinutes: 5,
    rating: 4.0,
    reviewCount: 38,
    tags: ['Sausage'],
  ),
  MenuItem(
    name: 'Beef Sandwich',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/Beef Sandwich.jpg',
    prepTimeMinutes: 10,
    rating: 4.6,
    reviewCount: 72,
    tags: ['Beef', 'Sandwich'],
  ),
  MenuItem(
    name: 'Chicken Sandwich',
    price: 8000,
    imagePath: 'assets/images/Katogo Beef/chicken sandwich.jpg',
    prepTimeMinutes: 10,
    rating: 4.7,
    reviewCount: 85,
    tags: ['Chicken', 'Sandwich'],
  ),
  MenuItem(
    name: 'Eggs Sandwich',
    price: 5000,
    imagePath: 'assets/images/Katogo Beef/Egg Sandwich.jpg',
    prepTimeMinutes: 8,
    rating: 4.4,
    reviewCount: 63,
    tags: ['Egg', 'Sandwich'],
    isVegetarian: true,
  ),
];

const burgers = [
  MenuItem(
    name: 'Plain Chicken Burger',
    price: 13000,
    imagePath: 'assets/images/Chicken Burger.jpg',
    prepTimeMinutes: 12,
    rating: 4.8,
    reviewCount: 156,
    tags: ['Chicken', 'Burger', 'Popular'],
  ),
  MenuItem(
    name: 'Beef Burger Plain',
    price: 11000,
    imagePath: 'assets/images/Beef Burger.jpg',
    prepTimeMinutes: 12,
    rating: 4.6,
    reviewCount: 134,
    tags: ['Beef', 'Burger', 'Popular'],
  ),
  MenuItem(
    name: 'Vegetable Burger Plain',
    price: 9000,
    imagePath: 'assets/images/Vegetable Burger.jpg',
    prepTimeMinutes: 10,
    rating: 4.3,
    reviewCount: 78,
    tags: ['Vegetarian', 'Burger'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Cheese Burger',
    price: 9000,
    imagePath: 'assets/images/Cheese Burger.jpg',
    prepTimeMinutes: 10,
    rating: 4.5,
    reviewCount: 92,
    tags: ['Burger', 'Cheese'],
  ),
];

const drinks = [
  MenuItem(
    name: 'Minute Maid',
    price: 3000,
    imagePath: 'assets/images/Minute Maid.jpg',
    rating: 4.2,
    reviewCount: 45,
    tags: ['Cold Drink', 'Juice'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Soda',
    price: 2000,
    imagePath: 'assets/images/Soda.jpg',
    rating: 4.0,
    reviewCount: 67,
    tags: ['Cold Drink'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Water',
    price: 2000,
    imagePath: 'assets/images/Water.jpg',
    rating: 4.1,
    reviewCount: 89,
    tags: ['Cold Drink'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Mixed Passion and Mangoes Juice',
    price: 4000,
    imagePath: 'assets/images/Mixed passion & mango.jpg',
    rating: 4.6,
    reviewCount: 56,
    tags: ['Juice', 'Popular'],
    isVegetarian: true,
  ),
];

const teas = [
  MenuItem(
    name: 'Black Tea',
    price: 3000,
    imagePath: 'assets/images/Black Tea.jpg',
    prepTimeMinutes: 5,
    rating: 4.3,
    reviewCount: 78,
    tags: ['Hot Drink', 'Tea'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'African Tea',
    price: 4000,
    imagePath: 'assets/images/African Tea.jpg',
    prepTimeMinutes: 7,
    rating: 4.7,
    reviewCount: 112,
    tags: ['Hot Drink', 'Tea', 'Popular'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Herbal Tea',
    price: 5000,
    imagePath: 'assets/images/Herbal Tea.jpg',
    prepTimeMinutes: 7,
    rating: 4.4,
    reviewCount: 67,
    tags: ['Hot Drink', 'Tea'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Hot Chocolate',
    price: 6000,
    imagePath: 'assets/images/Hot Chocolate.jpg',
    prepTimeMinutes: 7,
    rating: 4.8,
    reviewCount: 89,
    tags: ['Hot Drink', 'Popular'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'English Tea (Hot Water & Milk Aside)',
    price: 6000,
    imagePath: 'assets/images/English Tea.jpg',
    prepTimeMinutes: 8,
    rating: 4.5,
    reviewCount: 56,
    tags: ['Hot Drink', 'Tea'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Tea Masala',
    price: 5000,
    imagePath: 'assets/images/Tea Masala.jpg',
    prepTimeMinutes: 7,
    rating: 4.6,
    reviewCount: 78,
    tags: ['Hot Drink', 'Tea', 'Popular'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Dawa Tea (Lemon, Ginger, Cinnamon & Honey)',
    price: 6000,
    imagePath: 'assets/images/Dawa Tea.jpg',
    prepTimeMinutes: 8,
    rating: 4.9,
    reviewCount: 45,
    tags: ['Hot Drink', 'Tea', 'Popular'],
    isVegetarian: true,
  ),
  MenuItem(
    name: 'Iced Tea',
    price: 4000,
    imagePath: 'assets/images/Iced Tea.jpg',
    prepTimeMinutes: 5,
    rating: 4.3,
    reviewCount: 67,
    tags: ['Cold Drink', 'Tea'],
    isVegetarian: true,
  ),
];

const pizzas = [
  PizzaItem(
    name: 'Chicken Tikka Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/ChickenTikka.jpg',
    description: 'Spicy chicken tikka with bell peppers and onions',
  ),
  PizzaItem(
    name: 'Chicken BBQ Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Chicken BBq.jpg',
    description: 'BBQ chicken with red onions and cilantro',
  ),
  PizzaItem(
    name: 'Chicken and Mushroom Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Chicken Mushroom.jpg',
    description: 'Grilled chicken with fresh mushrooms',
  ),
  PizzaItem(
    name: 'Beef Tikka Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/BeefTikka.jpg',
    description: 'Spicy beef tikka with peppers and onions',
  ),
  PizzaItem(
    name: 'Vegetable Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Vegetable Pizza.jpg',
    description: 'Fresh vegetables with mozzarella cheese',
  ),
  PizzaItem(
    name: 'Hawaiian Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Hawaiin Pizza.jpg',
    description: 'Ham and pineapple with mozzarella',
  ),
  PizzaItem(
    name: 'Margherita Pizza',
    small: 25000,
    medium: 30000,
    large: 35000,
    imagePath: 'assets/images/Margherita Pizza.jpg',
    description: 'Classic tomato, basil, and mozzarella',
    isPopular: true,
  ),
  PizzaItem(
    name: 'Oweitu Pizza Special',
    small: 27000,
    medium: 35000,
    large: 40000,
    imagePath: 'assets/images/Oweitu Special.jpg',
    description: 'Our signature pizza with everything!',
    isPopular: true,
  ),
];

List<MenuItem> get allMenuItems {
  final List<MenuItem> all = [
    ...snacks,
    ...breakfast,
    ...burgers,
    ...drinks,
    ...teas,
  ];
  for (final p in pizzas) {
    all.add(
      MenuItem(
        name: p.name,
        price: p.small,
        imagePath: p.imagePath,
        note: 'from',
        description: p.description,
        rating: 4.5,
        reviewCount: 45,
      ),
    );
  }
  return all;
}

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

  Future<void> _completeAuth() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    AppScope.of(context).signIn();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/Login.jpg', fit: BoxFit.cover),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: _tabs.index == 0
                              ? _SignInForm(onSignIn: _completeAuth)
                              : _SignUpForm(onSignUp: _completeAuth),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Google',
                          color: Colors.white,
                          textColor: const Color(0xFF3C4043),
                          borderColor: const Color(0xFFDDDDDD),
                          icon: const _AssetLogo(
                            path:
                                'assets/images/google-logo-transparent-free-png-removebg-preview.png',
                          ),
                          onTap: () => _completeAuth(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialButton(
                          label: 'Phone',
                          color: AppColors.sage,
                          textColor: Colors.white,
                          icon: const Icon(
                            Icons.phone_android,
                            color: Colors.white,
                            size: 18,
                          ),
                          onTap: () => _completeAuth(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'TikTok',
                          color: Colors.black,
                          textColor: Colors.white,
                          icon: const _AssetLogo(
                            path: 'assets/images/Tiktok-removebg-preview.png',
                          ),
                          onTap: () => _completeAuth(),
                        ),
                      ),
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

class _SignInForm extends StatefulWidget {
  const _SignInForm({required this.onSignIn});
  final Future<void> Function() onSignIn;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _identifierError;
  String? _passwordError;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() {
      _identifierError = identifier.isEmpty
          ? 'Enter your email or phone'
          : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_identifierError != null || _passwordError != null) return;
    setState(() => _loading = true);
    await widget.onSignIn();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome to Oweitu Cafe',
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
        _InputField(
          hint: 'Email or phone number',
          controller: _identifierCtrl,
          keyboardType: TextInputType.emailAddress,
          errorText: _identifierError,
          onChanged: (_) => setState(() => _identifierError = null),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: 'Password',
          controller: _passwordCtrl,
          obscure: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) => setState(() => _passwordError = null),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppColors.mutedText,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
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
            onPressed: _loading ? null : _submit,
            child: _loading ? const _ButtonSpinner() : const Text('Sign In'),
          ),
        ),
      ],
    );
  }
}

class _SignUpForm extends StatefulWidget {
  const _SignUpForm({required this.onSignUp});
  final Future<void> Function() onSignUp;

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _nameCtrl = TextEditingController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _usePhone = false;
  bool _loading = false;
  String? _nameError;
  String? _identifierError;
  String? _passwordError;
  String? _confirmError;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    setState(() {
      _nameError = name.isEmpty ? 'Enter your full name' : null;
      _identifierError = identifier.isEmpty
          ? (_usePhone ? 'Enter your phone number' : 'Enter your email')
          : null;
      _passwordError = password.length < 6
          ? 'Password must be at least 6 characters'
          : null;
      _confirmError = confirm != password ? 'Passwords do not match' : null;
    });
    if (_nameError != null ||
        _identifierError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }
    setState(() => _loading = true);
    await widget.onSignUp();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

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
        _InputField(
          hint: 'Full name',
          controller: _nameCtrl,
          errorText: _nameError,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: 10),
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
                  onTap: () => setState(() {
                    _usePhone = false;
                    _identifierCtrl.clear();
                    _identifierError = null;
                  }),
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
                  onTap: () => setState(() {
                    _usePhone = true;
                    _identifierCtrl.clear();
                    _identifierError = null;
                  }),
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
          controller: _identifierCtrl,
          keyboardType: _usePhone
              ? TextInputType.phone
              : TextInputType.emailAddress,
          errorText: _identifierError,
          onChanged: (_) => setState(() => _identifierError = null),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: 'Password',
          controller: _passwordCtrl,
          obscure: _obscurePassword,
          errorText: _passwordError,
          onChanged: (_) => setState(() => _passwordError = null),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppColors.mutedText,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: 'Confirm password',
          controller: _confirmCtrl,
          obscure: _obscureConfirm,
          errorText: _confirmError,
          onChanged: (_) => setState(() => _confirmError = null),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: AppColors.mutedText,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const _ButtonSpinner()
                : const Text('Create Account'),
          ),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierCtrl = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _identifierError;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    final identifier = _identifierCtrl.text.trim();
    setState(() {
      _identifierError = identifier.isEmpty
          ? 'Enter your email or phone number'
          : null;
    });
    if (_identifierError != null) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

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
        _InputField(
          hint: 'Email or phone number',
          controller: _identifierCtrl,
          keyboardType: TextInputType.emailAddress,
          errorText: _identifierError,
          onChanged: (_) => setState(() => _identifierError = null),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _sendResetLink,
          child: _loading
              ? const _ButtonSpinner()
              : const Text('Send Reset Link'),
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

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.asset(path, width: 18, height: 18, fit: BoxFit.contain);
  }
}

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
    this.errorText,
  });
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final String? errorText;

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
        errorText: errorText,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

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
    final state = AppScope.of(context);
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
          if (state.isOffline)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OFFLINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs(context, 8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          _NotificationBell(),
          if (tabIndex == 1 || tabIndex == 0)
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

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final unreadCount = AppScope.of(context).unreadNotificationCount;
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

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final TextEditingController _promoController = TextEditingController();
  String? _promoError;
  bool _applyingPromo = false;
  bool _checkingOut = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cart = state.cart;
    final isDeliveryValid = state.isDeliveryValid;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
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
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 48,
                      color: AppColors.line,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: fs(context, 14),
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse our menu and add items you love!',
                      style: TextStyle(
                        fontSize: fs(context, 12),
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
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
                      child: Dismissible(
                        key: Key('${item.name}_${i}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          state.removeFromCart(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} removed'),
                              backgroundColor: AppColors.coral,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: fs(context, 13),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${MenuItem._fmt(item.price)} UGX',
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
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => state.setDeliveryType('Delivery'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: state.deliveryType == 'Delivery'
                                  ? AppColors.sage
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delivery_dining_outlined,
                                  size: 18,
                                  color: state.deliveryType == 'Delivery'
                                      ? Colors.white
                                      : AppColors.mutedText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Delivery',
                                  style: TextStyle(
                                    fontSize: fs(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: state.deliveryType == 'Delivery'
                                        ? Colors.white
                                        : AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => state.setDeliveryType('Takeaway'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: state.deliveryType == 'Takeaway'
                                  ? AppColors.sage
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 18,
                                  color: state.deliveryType == 'Takeaway'
                                      ? Colors.white
                                      : AppColors.mutedText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Takeaway',
                                  style: TextStyle(
                                    fontSize: fs(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: state.deliveryType == 'Takeaway'
                                        ? Colors.white
                                        : AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.deliveryType == 'Delivery')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
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
              if (state.deliveryType == 'Delivery' && !isDeliveryValid)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Minimum order of UGX 10,000 for delivery',
                            style: TextStyle(
                              fontSize: fs(context, 11),
                              color: AppColors.coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: state.promoCodeApplied != null
                          ? Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
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
                              errorText: _promoError,
                              onChanged: (_) =>
                                  setState(() => _promoError = null),
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
                          onPressed: _applyingPromo
                              ? null
                              : () => _applyPromo(context, state),
                          child: _applyingPromo
                              ? const _ButtonSpinner()
                              : Text(
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
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
                    if (state.deliveryType == 'Delivery' &&
                        state.deliveryFee > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Delivery',
                            style: TextStyle(
                              fontSize: fs(context, 13),
                              color: AppColors.mutedText,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            state.formattedDeliveryFee,
                            style: TextStyle(
                              fontSize: fs(context, 13),
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Row(
                      children: [
                        Text(
                          'Tax',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: AppColors.mutedText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          state.formattedTax,
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
                          state.formattedTotal,
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
                  onPressed: _checkingOut
                      ? null
                      : () async {
                          if (!state.isAuthenticated) {
                            requestCheckoutAuth(
                              context,
                              state,
                              closeCurrent: true,
                            );
                            return;
                          }
                          if (state.deliveryType == 'Delivery' &&
                              !isDeliveryValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Minimum order of UGX 10,000 required for delivery',
                                ),
                                backgroundColor: AppColors.coral,
                              ),
                            );
                            return;
                          }
                          if (state.deliveryType == 'Delivery' &&
                              state.selectedAddress == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please add a delivery address'),
                                backgroundColor: AppColors.coral,
                              ),
                            );
                            return;
                          }
                          setState(() => _checkingOut = true);
                          await Future<void>.delayed(
                            const Duration(milliseconds: 250),
                          );
                          if (!context.mounted) return;
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
                  child: _checkingOut
                      ? const _ButtonSpinner()
                      : const Text('Proceed to Checkout'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyPromo(BuildContext context, AppState state) async {
    FocusScope.of(context).unfocus();
    final code = _promoController.text.trim();
    setState(() {
      _promoError = code.isEmpty ? 'Enter a promo code' : null;
    });
    if (_promoError != null) return;
    setState(() => _applyingPromo = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!context.mounted) return;
    setState(() => _applyingPromo = false);
    if (!state.applyPromo(code)) {
      setState(() => _promoError = 'Invalid promo code');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid promo code')));
    }
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

class AddressPickerSheet extends StatelessWidget {
  const AddressPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final addresses = _getAddresses();

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
          ...addresses.map(
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gps_fixed, size: 14, color: AppColors.sage),
              const SizedBox(width: 4),
              Text(
                'Use current location',
                style: TextStyle(
                  fontSize: fs(context, 12),
                  color: AppColors.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DeliveryAddress> _getAddresses() {
    return [
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
  }
}

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _addressCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  String _selectedLabel = 'Home';
  String? _addressError;
  bool _saving = false;

  final List<String> _quickLabels = ['Home', 'Work', 'Hotel', 'Other'];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    FocusScope.of(context).unfocus();
    final address = _addressCtrl.text.trim();
    setState(() {
      _addressError = address.isEmpty ? 'Enter a delivery address' : null;
    });
    if (_addressError != null) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final addr = DeliveryAddress(
      label: _selectedLabel,
      fullAddress: address,
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
    );
    AppScope.of(context).setAddress(addr);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address saved!'),
        backgroundColor: AppColors.sage,
      ),
    );
  }

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
          Wrap(
            spacing: 8,
            children: _quickLabels
                .map(
                  (label) => GestureDetector(
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
            errorText: _addressError,
            onChanged: (_) => setState(() => _addressError = null),
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
            onPressed: _saving ? null : _saveAddress,
            child: _saving
                ? const _ButtonSpinner()
                : const Text('Save Address'),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'Mobile Money';
  bool _placingOrder = false;
  bool _useLoyaltyPoints = false;
  final List<String> _paymentMethods = [
    'Mobile Money',
    'Cash on Delivery',
    'Card',
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isDeliveryValid = state.isDeliveryValid;

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
          _SectionHeader(title: 'Delivery Type'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => state.setDeliveryType('Delivery'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: state.deliveryType == 'Delivery'
                            ? AppColors.sage
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining_outlined,
                            size: 18,
                            color: state.deliveryType == 'Delivery'
                                ? Colors.white
                                : AppColors.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery',
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              fontWeight: FontWeight.w700,
                              color: state.deliveryType == 'Delivery'
                                  ? Colors.white
                                  : AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => state.setDeliveryType('Takeaway'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: state.deliveryType == 'Takeaway'
                            ? AppColors.sage
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: state.deliveryType == 'Takeaway'
                                ? Colors.white
                                : AppColors.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Takeaway',
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              fontWeight: FontWeight.w700,
                              color: state.deliveryType == 'Takeaway'
                                  ? Colors.white
                                  : AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (state.deliveryType == 'Delivery') ...[
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
          ],
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
                if (state.deliveryType == 'Delivery') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Delivery Fee',
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: AppColors.mutedText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          state.formattedDeliveryFee,
                          style: TextStyle(
                            fontSize: fs(context, 13),
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tax',
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          color: AppColors.mutedText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        state.formattedTax,
                        style: TextStyle(
                          fontSize: fs(context, 13),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        state.formattedTotal,
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 20,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loyalty Points Available: ${state.loyaltyPoints} pts',
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '1,000 pts = UGX 10,000 discount',
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.loyaltyPoints >= 1000)
                  Switch(
                    value: _useLoyaltyPoints,
                    onChanged: (v) => setState(() => _useLoyaltyPoints = v),
                    activeColor: AppColors.sage,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: ElevatedButton(
          onPressed: state.cart.isEmpty || _placingOrder
              ? null
              : () async {
                  if (!state.isAuthenticated) {
                    requestCheckoutAuth(context, state);
                    return;
                  }
                  if (state.deliveryType == 'Delivery' && !isDeliveryValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Minimum order of UGX 10,000 required for delivery',
                        ),
                        backgroundColor: AppColors.coral,
                      ),
                    );
                    return;
                  }
                  if (state.deliveryType == 'Delivery' &&
                      state.selectedAddress == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add a delivery address'),
                        backgroundColor: AppColors.coral,
                      ),
                    );
                    return;
                  }
                  setState(() => _placingOrder = true);
                  await Future<void>.delayed(const Duration(milliseconds: 300));
                  if (!context.mounted) return;
                  state.placeOrder();
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
          child: _placingOrder
              ? const _ButtonSpinner()
              : Text(
                  'Place Order • ${state.formattedTotal}',
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

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  double _rating = 0;
  bool _showRating = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final order = state.orders.where((o) => o.id == widget.orderId).firstOrNull;

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
                  widget.orderId,
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
              if (order != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Estimated delivery: ${order.estimatedMinutes ?? 25} min',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fs(context, 13),
                    fontWeight: FontWeight.w600,
                    color: AppColors.sage,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: AppScope.of(context),
                        child: OrderTrackingScreen(orderId: widget.orderId),
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
              if (!_showRating)
                TextButton(
                  onPressed: () => setState(() => _showRating = true),
                  child: Text(
                    'Rate your experience',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: fs(context, 12),
                    ),
                  ),
                ),
              if (_showRating) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      onPressed: () => setState(() => _rating = i + 1.0),
                      icon: Icon(
                        i < _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
              ],
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

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final order = state.orders.where((o) => o.id == orderId).firstOrNull;

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
        actions: [
          if (order != null &&
              order.status.index <= OrderStatus.confirmed.index)
            TextButton(
              onPressed: () => _showCancelDialog(context, state, orderId),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                  const SizedBox(height: 4),
                  Text(
                    order.deliveryType == 'Takeaway' ? 'Takeaway' : 'Delivery',
                    style: TextStyle(
                      fontSize: fs(context, 11),
                      color: AppColors.sage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated: ${order.estimatedTime}',
                    style: TextStyle(
                      fontSize: fs(context, 11),
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
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
          if (order != null && order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate Your Order',
                    style: TextStyle(
                      fontSize: fs(context, 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () {
                          final updatedOrder = state.orders
                              .where((o) => o.id == orderId)
                              .firstOrNull;
                          if (updatedOrder != null) {
                            updatedOrder.rating = i + 1.0;
                            state.notifyListeners();
                          }
                        },
                        icon: Icon(
                          i < (order.rating ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  if (order.review.isNotEmpty)
                    Text(
                      order.review,
                      style: TextStyle(
                        fontSize: fs(context, 12),
                        color: AppColors.grayText,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              state.reorder(orderId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Items added to cart!'),
                  backgroundColor: AppColors.sage,
                ),
              );
            },
            icon: const Icon(Icons.repeat, size: 18),
            label: const Text('Reorder'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AppScope(state: state, child: const OrderHistoryScreen()),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('View All Orders'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppState state, String orderId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              state.cancelOrder(orderId);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order cancelled'),
                  backgroundColor: AppColors.coral,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('Yes, Cancel'),
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

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders;

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
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (itemContext, i) {
                final order = orders[i];
                return GestureDetector(
                  onTap: () => Navigator.of(itemContext).push(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        state: AppScope.of(itemContext),
                        child: OrderTrackingScreen(orderId: order.id),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: order.status == OrderStatus.cancelled
                          ? Colors.grey.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: order.status == OrderStatus.cancelled
                            ? Colors.grey.shade300
                            : AppColors.line,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              order.statusIcon,
                              size: 18,
                              color: order.status == OrderStatus.cancelled
                                  ? Colors.grey
                                  : AppColors.sage,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.statusLabel,
                              style: TextStyle(
                                fontSize: fs(context, 13),
                                fontWeight: FontWeight.w700,
                                color: order.status == OrderStatus.cancelled
                                    ? Colors.grey
                                    : AppColors.sage,
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              order.deliveryType == 'Takeaway'
                                  ? 'Takeaway'
                                  : 'Delivery',
                              style: TextStyle(
                                fontSize: fs(context, 10),
                                color: AppColors.sage,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (order.rating > 0) ...[
                              const SizedBox(width: 8),
                              Row(
                                children: List.generate(5, (j) {
                                  return Icon(
                                    j < order.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 12,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ],
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
                                onPressed: () => Navigator.of(itemContext).push(
                                  MaterialPageRoute(
                                    builder: (_) => AppScope(
                                      state: AppScope.of(itemContext),
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
                                  AppScope.of(itemContext).reorder(order.id);
                                  ScaffoldMessenger.of(
                                    itemContext,
                                  ).showSnackBar(
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.notifications;
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
            onPressed: state.unreadNotificationCount == 0
                ? null
                : state.markAllNotificationsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      body: items.isEmpty
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
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.line, height: 1),
              itemBuilder: (_, i) {
                final notif = items[i];
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

class AppNotification {
  const AppNotification({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
  });
  final IconData icon;
  final String title, body, time;
  final bool unread;

  AppNotification copyWith({bool? unread}) {
    return AppNotification(
      icon: icon,
      title: title,
      body: body,
      time: time,
      unread: unread ?? this.unread,
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<MenuItem> _results = [];
  bool _searched = false;
  String? _filter;
  String? _sortBy;
  final List<String> _dietaryFilters = ['All', 'Vegetarian', 'Gluten Free'];
  final List<String> _sortOptions = [
    'Popularity',
    'Price: Low to High',
    'Price: High to Low',
    'Rating',
  ];
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        setState(() {
          _results = [];
          _searched = false;
        });
        return;
      }
      AppScope.of(context).addSearchHistory(q);
      var matches = allMenuItems
          .where((item) => item.name.toLowerCase().contains(q))
          .toList();
      _applyFilters(matches);
    });
  }

  void _applyFilters(List<MenuItem> matches) {
    if (_filter != null && _filter != 'All') {
      if (_filter == 'Vegetarian') {
        matches = matches.where((item) => item.isVegetarian).toList();
      } else if (_filter == 'Gluten Free') {
        matches = matches.where((item) => item.isGlutenFree).toList();
      }
    }
    if (_sortBy == 'Popularity') {
      matches.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    } else if (_sortBy == 'Price: Low to High') {
      matches.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'Price: High to Low') {
      matches.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'Rating') {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
    }
    setState(() {
      _results = matches;
      _searched = true;
    });
  }

  void _clearSearch() {
    _ctrl.clear();
    _searched = false;
    _results = [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
                      onPressed: _clearSearch,
                    )
                  : null,
            ),
          ),
          if (state.searchHistory.isNotEmpty && !_searched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontSize: fs(context, 12),
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedText,
                        ),
                      ),
                      TextButton(
                        onPressed: state.clearSearchHistory,
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: fs(context, 11),
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: state.searchHistory.map((query) {
                      return GestureDetector(
                        onTap: () {
                          _ctrl.text = query;
                          _search(query);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            query,
                            style: TextStyle(
                              fontSize: fs(context, 12),
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          if (_searched)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._dietaryFilters.map((filter) {
                      final selected =
                          _filter == filter ||
                          (filter == 'All' && _filter == null);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filter = filter == 'All' ? null : filter;
                              _search(_ctrl.text);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.sage
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.sage
                                    : AppColors.line,
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: fs(context, 11),
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.mutedText,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButton<String>(
                        hint: Text(
                          'Sort',
                          style: TextStyle(
                            fontSize: fs(context, 11),
                            color: AppColors.mutedText,
                          ),
                        ),
                        value: _sortBy,
                        items: _sortOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(
                              option,
                              style: TextStyle(fontSize: fs(context, 11)),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value;
                            _search(_ctrl.text);
                          });
                        },
                        underline: const SizedBox(),
                      ),
                    ),
                  ],
                ),
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
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
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
                  ? Image.asset(
                      item.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.placeholder,
                        child: Icon(
                          Icons.broken_image,
                          color: AppColors.mutedText,
                        ),
                      ),
                    )
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fs(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
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
                    if (item.rating > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      Text(
                        '${item.rating}',
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.tags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: item.tags.take(2).map((tag) {
                      return Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: fs(context, 9),
                          color: AppColors.mutedText,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          if (item.available)
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
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Out of Stock',
                style: TextStyle(
                  fontSize: fs(context, 9),
                  color: AppColors.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final favItems = allMenuItems
        .where((item) => state.isFavorite(item.name))
        .toList();

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

class DealsScreen extends StatelessWidget {
  const DealsScreen({super.key});

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
        separatorBuilder: (context, index) => const SizedBox(height: 14),
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
                          Clipboard.setData(ClipboardData(text: deal.code!));
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
          Expanded(
            child: _tabs.index == 0
                ? const _SendGiftTab()
                : const _RedeemGiftTab(),
          ),
        ],
      ),
    );
  }
}

class _SendGiftTab extends StatefulWidget {
  const _SendGiftTab();

  @override
  State<_SendGiftTab> createState() => _SendGiftTabState();
}

class _SendGiftTabState extends State<_SendGiftTab> {
  static const List<int> _amounts = [10000, 20000, 50000, 100000];
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _selected = 20000;
  bool _sending = false;
  String? _recipientNameError;
  String? _recipientPhoneError;

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendGiftCard() async {
    FocusScope.of(context).unfocus();
    final name = _recipientNameCtrl.text.trim();
    final phone = _recipientPhoneCtrl.text.trim();
    setState(() {
      _recipientNameError = name.isEmpty ? "Enter recipient's name" : null;
      _recipientPhoneError = phone.isEmpty ? "Enter recipient's phone" : null;
    });
    if (_recipientNameError != null || _recipientPhoneError != null) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gift card sent successfully!'),
        backgroundColor: AppColors.sage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
          children: _amounts.map((amt) {
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selected = amt),
                child: Container(
                  margin: EdgeInsets.only(right: amt != _amounts.last ? 8 : 0),
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selected == amt
                        ? AppColors.sage
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selected == amt ? AppColors.sage : AppColors.line,
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
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _InputField(
          hint: "Recipient's name",
          controller: _recipientNameCtrl,
          errorText: _recipientNameError,
          onChanged: (_) => setState(() => _recipientNameError = null),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: "Recipient's phone number",
          controller: _recipientPhoneCtrl,
          keyboardType: TextInputType.phone,
          errorText: _recipientPhoneError,
          onChanged: (_) => setState(() => _recipientPhoneError = null),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: 'Personal message (optional)',
          controller: _messageCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _sending ? null : _sendGiftCard,
          child: _sending
              ? const _ButtonSpinner()
              : Text('Send Gift Card • UGX ${MenuItem._fmt(_selected)}'),
        ),
      ],
    );
  }
}

class _RedeemGiftTab extends StatefulWidget {
  const _RedeemGiftTab();

  @override
  State<_RedeemGiftTab> createState() => _RedeemGiftTabState();
}

class _RedeemGiftTabState extends State<_RedeemGiftTab> {
  final _codeCtrl = TextEditingController();
  String? _codeError;
  bool _redeeming = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    FocusScope.of(context).unfocus();
    final code = _codeCtrl.text.trim();
    setState(() {
      _codeError = code.isEmpty ? 'Enter a gift card code' : null;
    });
    if (_codeError != null) return;
    setState(() => _redeeming = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _redeeming = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gift card redeemed! Credit added to your account.'),
        backgroundColor: AppColors.sage,
      ),
    );
  }

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
          _InputField(
            hint: 'Gift card code (e.g. OWGFT-XXXX-XXXX)',
            controller: _codeCtrl,
            errorText: _codeError,
            onChanged: (_) => setState(() => _codeError = null),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _redeeming ? null : _redeem,
            child: _redeeming ? const _ButtonSpinner() : const Text('Redeem'),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _orderNotifs = true;
  bool _promoNotifs = true;
  bool _emailUpdates = false;
  bool _biometricAuth = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final state = AppScope.of(context);
    _biometricAuth = state.isBiometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
            title: 'PREFERENCES',
            children: [
              _SwitchRow(
                label: 'Dark Mode',
                value: state.darkMode,
                onChanged: (v) => state.toggleDarkMode(),
              ),
              _NavRow(
                label: 'Language',
                trailing: Text(
                  state.selectedLanguage,
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: AppColors.mutedText,
                  ),
                ),
                onTap: () => _showLanguageDialog(context, state),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            title: 'SECURITY',
            children: [
              _NavRow(
                label: 'Change Password',
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'ACCOUNT',
            children: [
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
              _NavRow(
                label: 'Clear Cache',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared!'),
                      backgroundColor: AppColors.sage,
                    ),
                  );
                },
              ),
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
              'Oweitu Cafe App v1.3.3\n© 2026 Oweitu Cafe. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs(context, 11),
                color: AppColors.mutedText,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          state.signOut();
                          Navigator.pop(dialogContext);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.coral,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w700,
                  fontSize: fs(context, 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Swahili', 'Luganda'].map((lang) {
            return ListTile(
              title: Text(lang),
              trailing: state.selectedLanguage == lang
                  ? Icon(Icons.check, color: AppColors.sage)
                  : null,
              onTap: () {
                state.setLanguage(lang);
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InputField(
              hint: 'Current Password',
              controller: currentCtrl,
              obscure: true,
            ),
            const SizedBox(height: 8),
            _InputField(
              hint: 'New Password',
              controller: newCtrl,
              obscure: true,
            ),
            const SizedBox(height: 8),
            _InputField(
              hint: 'Confirm Password',
              controller: confirmCtrl,
              obscure: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newCtrl.text == confirmCtrl.text &&
                  newCtrl.text.length >= 6) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully!'),
                    backgroundColor: AppColors.sage,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match or are too short'),
                    backgroundColor: AppColors.coral,
                  ),
                );
              }
            },
            child: const Text('Update'),
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
            activeThumbColor: AppColors.sage,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, this.onTap, this.trailing});
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

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
            if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
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

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitted = false;
  bool _sending = false;
  String? _subjectError;
  String? _messageError;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    FocusScope.of(context).unfocus();
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    setState(() {
      _subjectError = subject.isEmpty ? 'Enter a subject' : null;
      _messageError = message.isEmpty ? 'Describe your issue' : null;
    });
    if (_subjectError != null || _messageError != null) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _sending = false;
      _submitted = true;
    });
  }

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
        _InputField(
          hint: 'Subject',
          controller: _subjectCtrl,
          errorText: _subjectError,
          onChanged: (_) => setState(() => _subjectError = null),
        ),
        const SizedBox(height: 10),
        _InputField(
          hint: 'Describe your issue...',
          controller: _messageCtrl,
          maxLines: 5,
          errorText: _messageError,
          onChanged: (_) => setState(() => _messageError = null),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _sending ? null : _sendMessage,
          child: _sending ? const _ButtonSpinner() : const Text('Send Message'),
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
            'Oweitu Cafe is a homegrown café & restaurant based in Mbarara City, Uganda. We believe great food should be accessible, affordable, and always freshly prepared.\n\nFrom our beloved chapati and katogo breakfasts to freshly baked pizzas and crispy fried chicken, every dish is made with care and quality ingredients.',
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
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: 'Mbarara City, Uganda (Former SABS)',
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.schedule_outlined, text: 'Mon–Sun: 24/7'),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.phone_outlined,
            text: '+256 705701185 , +256 784283433',
          ),
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
            child: Image.asset(
              _imagePaths[i],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.placeholder,
                child: Icon(
                  Icons.broken_image,
                  size: 40,
                  color: AppColors.mutedText,
                ),
              ),
            ),
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
              child: Center(
                child: Image.asset(
                  _imagePaths[i],
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 80,
                  ),
                ),
              ),
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: widget.item.imagePath != null
                  ? Image.asset(
                      widget.item.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.placeholder,
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: AppColors.mutedText,
                        ),
                      ),
                    )
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
                if (widget.item.rating > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < widget.item.rating
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '(${widget.item.reviewCount} reviews)',
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
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
                if (widget.item.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: widget.item.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: fs(context, 10),
                            color: AppColors.sage,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (widget.item.prepTimeMinutes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.item.prepTimeMinutes} min prep time',
                        style: TextStyle(
                          fontSize: fs(context, 11),
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onStartOrder});
  final VoidCallback onStartOrder;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders;
    final sw = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        children: [
          if (state.isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.coral,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'You are offline. Some features may be limited.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fs(context, 11),
                    ),
                  ),
                ],
              ),
            ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    if (orders.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AppScope(
                              state: AppScope.of(context),
                              child: const OrderHistoryScreen(),
                            ),
                          ),
                        ),
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontSize: fs(context, 11),
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                  ],
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
                    children: orders.take(2).map((order) {
                      return Padding(
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
                              color: order.status == OrderStatus.cancelled
                                  ? Colors.grey.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: order.status == OrderStatus.cancelled
                                    ? Colors.grey.shade300
                                    : AppColors.line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  order.statusIcon,
                                  size: 20,
                                  color: order.status == OrderStatus.cancelled
                                      ? Colors.grey
                                      : AppColors.sage,
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
                                          color:
                                              order.status ==
                                                  OrderStatus.cancelled
                                              ? Colors.grey
                                              : AppColors.sage,
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
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
                    Image.asset(
                      category.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.placeholder,
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
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
                        : Image.asset(
                            item.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: AppColors.placeholder,
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                          ),
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
                    if (item.isPopular)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fs(context, 8),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (!item.available)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.black.withValues(alpha: 0.7),
                          child: Text(
                            'OUT OF STOCK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fs(context, 10),
                              fontWeight: FontWeight.w800,
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
                        Row(
                          children: [
                            Text(
                              item.priceFormatted,
                              style: TextStyle(
                                fontSize: fs(context, 12),
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            if (item.rating > 0) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.star, size: 10, color: Colors.amber),
                              Text(
                                '${item.rating}',
                                style: TextStyle(
                                  fontSize: fs(context, 10),
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 30,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: item.available
                                  ? AppColors.sage
                                  : AppColors.placeholder,
                              foregroundColor: item.available
                                  ? Colors.white
                                  : AppColors.mutedText,
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
                            onPressed: item.available
                                ? () => state.addToCart(item)
                                : null,
                            child: Text(
                              item.available ? 'ORDER' : 'UNAVAILABLE',
                            ),
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
                          : Image.asset(
                              pizza.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: AppColors.placeholder,
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 40,
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                            ),
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
                      if (pizza.isPopular)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'POPULAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: fs(context, 8),
                                fontWeight: FontWeight.w800,
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

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const RewardsBanner(),
        const SizedBox(height: 14),
        PointsCard(points: state.loyaltyPoints),
        const SizedBox(height: 14),
        const HowItWorks(),
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
  const PointsCard({super.key, this.points = 80});
  final int points;

  @override
  Widget build(BuildContext context) {
    final progress = points / 1000;
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
            '${points} pts',
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
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final state = AppScope.of(context);
    _nameCtrl.text = state.profileName;
    _emailCtrl.text = state.profileEmail;
    _phoneCtrl.text = state.profilePhone;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
              if (!_isEditing) _loadProfile();
            },
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  // Show image picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Image picker would open here'),
                      backgroundColor: AppColors.sage,
                    ),
                  );
                }
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ProfileAvatar(size: 110, imagePath: state.profileImagePath),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              _InputField(hint: 'Full Name', controller: _nameCtrl),
              const SizedBox(height: 10),
              _InputField(
                hint: 'Email',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _InputField(
                hint: 'Phone',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  state.updateProfile(
                    name: _nameCtrl.text.trim(),
                    email: _emailCtrl.text.trim(),
                    phone: _phoneCtrl.text.trim(),
                  );
                  setState(() => _isEditing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated!'),
                      backgroundColor: AppColors.sage,
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ] else ...[
              Center(
                child: Text(
                  state.profileName,
                  style: TextStyle(
                    fontSize: fs(context, 20),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ProfileLine(icon: Icons.mail_outline, text: state.profileEmail),
              const SizedBox(height: 20),
              ProfileLine(icon: Icons.phone_android, text: state.profilePhone),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${state.loyaltyPoints} Loyalty Points',
                      style: TextStyle(
                        fontSize: fs(context, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: ProfileAvatar(size: 80, imagePath: state.profileImagePath),
            ),
            const SizedBox(height: 12),
            Text(
              state.profileName,
              style: TextStyle(
                fontSize: fs(context, 15),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              state.profileEmail,
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
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          state.signOut();
                          Navigator.pop(dialogContext);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.coral,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
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
  const ProfileAvatar({super.key, required this.size, this.imagePath});
  final double size;
  final String? imagePath;

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
          child: imagePath != null
              ? ClipOval(
                  child: Image.asset(
                    imagePath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_outline,
                      size: size * 0.50,
                      color: Colors.black87,
                    ),
                  ),
                )
              : Icon(
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
