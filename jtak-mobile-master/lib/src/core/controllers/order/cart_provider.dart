import 'package:flutter/foundation.dart';
import 'package:jtek_app/src/core/controllers/order/order_payment_provider.dart';
import 'package:jtek_app/src/core/controllers/order/order_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/enums/order_details_status_enum.dart';
import 'package:jtek_app/src/core/models/order/local_cart_item.dart';
import 'package:jtek_app/src/core/models/order/order_details_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/constants/shard_preference_kay.dart';
import '../../../utils/providers/sol_api.dart';
import '../catalog/markets_provider.dart';
import '../../data/mock_catalog_data.dart';
import '../../enums/viewstate.dart';
import '../../models/order/order_model.dart';
import '../../services/authentication_service.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';
import 'cart_info.dart';

class CartProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  CartInfo cartInfo = CartInfo();
  OrderPaymentProvider orderPayment = OrderPaymentProvider();
  OrderModel order = OrderModel(orderDetails: []);
  List<LocalCartItem> localCartItems = [];

  int count = 0;

  int get totalQuantity {
    return localCartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int? get currentMerchantId {
    if (localCartItems.isEmpty) return null;
    return localCartItems.first.merchantId;
  }

  int get currentMerchantMinOrder {
    if (localCartItems.isEmpty) return 0;
    final mId = currentMerchantId;
    if (mId != null && mId > 0) {
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        final mStore = prov.markets.where((m) => m.id == mId).firstOrNull;
        if (mStore != null && mStore.minOrderAmount > 0) return mStore.minOrderAmount;
        final rStore = prov.restaurants.where((r) => r.id == mId).firstOrNull;
        if (rStore != null && rStore.minOrderAmount > 0) return rStore.minOrderAmount;
      }
      try {
        final rest = MockCatalogData.getRestaurantById(mId);
        return rest.minOrder;
      } catch (_) {}
    }
    return 0;
  }

  double get deliveryFee {
    if (localCartItems.isEmpty) return 0.0;
    final mId = currentMerchantId;
    if (mId != null && mId > 0) {
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        final mStore = prov.markets.where((m) => m.id == mId).firstOrNull;
        if (mStore != null && mStore.deliveryFeeAmount > 0) return mStore.deliveryFeeAmount;
        final rStore = prov.restaurants.where((r) => r.id == mId).firstOrNull;
        if (rStore != null && rStore.deliveryFeeAmount > 0) return rStore.deliveryFeeAmount;
      }
      try {
        final rest = MockCatalogData.getRestaurantById(mId);
        final fee = double.tryParse(rest.deliveryFee.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (fee != null && fee > 0) return fee;
      } catch (_) {}
    }
    return 5000.0;
  }

  String get currentMerchantName {
    if (localCartItems.isEmpty) return '';
    final mId = localCartItems.first.merchantId;
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      final name = order.orderDetails!.first.merchantTitle;
      if (name != null && name.isNotEmpty) return name.split(' - ').first;
    }
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final mStore = prov.markets.where((m) => m.id == mId).firstOrNull;
      if (mStore != null && mStore.name.isNotEmpty) return mStore.name.split(' - ').first;
      final rStore = prov.restaurants.where((r) => r.id == mId).firstOrNull;
      if (rStore != null && rStore.name.isNotEmpty) return rStore.name.split(' - ').first;
    }
    final mockItem =
        MockCatalogData.getMenuItemById(localCartItems.first.productId);
    if (mockItem?.restaurantName != null &&
        mockItem!.restaurantName.isNotEmpty) {
      return mockItem.restaurantName.split(' - ').first;
    }
    if (mId > 0) {
      try {
        final rest = MockCatalogData.getRestaurantById(mId);
        return rest.name.split(' - ').first;
      } catch (_) {}
    }
    return 'المتجر السابق';
  }

  bool isDifferentMerchant(int newMerchantId) {
    if (localCartItems.isEmpty || newMerchantId <= 0) return false;
    return localCartItems
        .any((item) => item.merchantId > 0 && item.merchantId != newMerchantId);
  }

  Future<void> replaceCartWithItem(int productId, int merchantId,
      double singleFinalPrice, int quantity) async {
    localCartItems.clear();
    order = OrderModel(orderDetails: []);
    count = 0;
    await _removeLocalCart();
    await setToCart(productId, merchantId, singleFinalPrice, quantity);
  }

  int getProductQuantity(int? productId) {
    if (productId == null) return 0;
    for (final item in localCartItems) {
      if (item.productId == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  Future submitOrder() async {
    if (state == ViewState.busy) {
      debugPrint('CartProvider.submitOrder: Submission already in flight, ignoring duplicate call.');
      return;
    }
    try {
      setState(ViewState.busy);
      var cartItems = _getCartJsonBody(localCartItems);

      // Clean & Sanitize Phone Number to valid format
      String rawPhone = cartInfo.phoneNumber?.phoneNumber ??
          locator<AuthenticationService>().user?.phoneNumber ??
          '';
      String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.isEmpty) {
        throw Exception('يرجى تسجيل الدخول أولاً');
      }

      final mainAddress =
          locator<AppParametersProvider>().mainAddressService.mainAddress;
      final lat = cartInfo.lat ?? mainAddress.lat;
      final lng = cartInfo.lng ?? mainAddress.lng;
      final address = cartInfo.address ?? mainAddress.fullAddress;
      if (lat == null ||
          lng == null ||
          address == null ||
          address.trim().isEmpty) {
        throw Exception(
            'يرجى اختيار عنوان التوصيل على الخريطة قبل إتمام الطلب.');
      }

      final String idempotencyKey =
          'ord_${DateTime.now().millisecondsSinceEpoch}_${cleanPhone}_${cartItems.length}';

      Map<String, dynamic> body = {
        "cartItems": cartItems,
        "phonenumber": cleanPhone,
        "lat": lat,
        "lng": lng,
        "name": cartInfo.name ??
            locator<AuthenticationService>().user?.fullName ??
            'عميل جيتك',
        "address": address,
        "paymentMethod": orderPayment.paymentMethod.index,
        "idempotencyKey": idempotencyKey,
      };

      final response = await _api.postRequest('/Cart/SubmitOrder', body);
      if (response == null || response is! Map || response['id'] == null) {
        throw Exception(
            'The server did not create the order. Please try again.');
      }
      final int newOrderId = (response['id'] as num).toInt();
      debugPrint('Successfully submitted live order #$newOrderId to backend!');

      // Create and persist placed OrderModel for real-time tracking
      final double finalTotal = order.price ??
          localCartItems.fold(
              0.0, (s, i) => s + (i.singleFinalPrice * i.quantity));
      final List<OrderDetailsModel> details =
          (order.orderDetails != null && order.orderDetails!.isNotEmpty)
              ? order.orderDetails!
                  .map((d) => OrderDetailsModel(
                        productId: d.productId,
                        merchantId: d.merchantId,
                        merchantTitle: d.merchantTitle,
                        productTitle: d.productTitle,
                        singlePrice: d.singlePrice,
                        singleFinalPrice: d.singleFinalPrice,
                        quantity: d.quantity,
                        totalPrice: d.totalPrice,
                        totalFinalPrice: d.totalFinalPrice,
                        productImage: d.productImage,
                        orderDetailStatus:
                            d.orderDetailStatus ?? OrderDetailsStatus.pending,
                      ))
                  .toList()
              : localCartItems.map((item) {
                  final mock = MockCatalogData.getMenuItemById(item.productId);
                  return OrderDetailsModel(
                    productId: item.productId,
                    merchantId: item.merchantId,
                    merchantTitle: mock?.restaurantName ?? 'متجر جيتك',
                    productTitle: mock?.title ?? 'وجبة خاصة',
                    singlePrice: item.singleFinalPrice,
                    singleFinalPrice: item.singleFinalPrice,
                    quantity: item.quantity,
                    totalPrice: item.singleFinalPrice * item.quantity,
                    totalFinalPrice: item.singleFinalPrice * item.quantity,
                    productImage: mock?.imageUrl ?? '',
                    orderDetailStatus: OrderDetailsStatus.pending,
                  );
                }).toList();

      final placedOrder = OrderModel(
        id: newOrderId,
        purchaseDate: DateTime.now().toIso8601String(),
        price: finalTotal,
        phonenumber: cleanPhone,
        address: address,
        description:
            details.isNotEmpty ? details.first.merchantTitle : 'متجر جيتك',
        orderDetails: details,
      );

      await OrderProvider.saveNewOrderGlobally(placedOrder);

      await resetData();
      setState(ViewState.idle);
    } catch (err) {
      setState(ViewState.idle);
      debugPrint('SubmitOrder error: $err');
      rethrow;
    }
  }

  Future loadCart() async {
    try {
      setState(ViewState.busy);
      if (localCartItems.isEmpty) {
        await loadLocalCart();
      }
      if (localCartItems.isNotEmpty) {
        order = await _calcCart(localCartItems);
      } else {
        order = OrderModel(orderDetails: []);
      }
      setState(ViewState.idle);
    } catch (err) {
      setState(ViewState.idle);
      debugPrint(err.toString());
    }
  }

  Future<OrderModel> _calcCart(List<LocalCartItem> items) async {
    final mainAddress =
        locator<AppParametersProvider>().mainAddressService.mainAddress;
    final lat = cartInfo.lat ?? mainAddress.lat ?? 33.5138;
    final lng = cartInfo.lng ?? mainAddress.lng ?? 36.2765;
    final response = await _api.postRequest(
      '/Cart/Calc/$lat/$lng',
      _getCartJsonBody(items),
    );
    if (response is! Map) {
      throw Exception('The server could not validate the cart.');
    }
    return OrderModel.fromMap(Map<String, dynamic>.from(response));
  }

  List<Map<String, dynamic>> _getCartJsonBody(List<LocalCartItem> items) {
    List<Map<String, dynamic>> body = [];
    for (var element in items) {
      body.add(element.toMap());
    }
    return body;
  }

  LocalCartItem? findItme(int productId, int merchantId) {
    for (var item in localCartItems) {
      if (item.productId == productId && item.merchantId == merchantId) {
        return item;
      }
    }
    return null;
  }

  Future removeFromCart(int productId, int merchantId) async {
    try {
      _setToLocalCart(productId, merchantId, 0.0, 0);
      order = await _calcCart(localCartItems);
      notifyListeners();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future addToCart(int productId, int merchantId, double singleFinalPrice,
      {int quantity = 1}) async {
    try {
      final current =
          _findInLocalCart(localCartItems, productId, merchantId)?.quantity ??
              0;
      _setToLocalCart(
          productId, merchantId, singleFinalPrice, current + quantity);
      order = await _calcCart(localCartItems);
      notifyListeners();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future setToCart(int productId, int merchantId, double singleFinalPrice,
      int quantity) async {
    try {
      _setToLocalCart(productId, merchantId, singleFinalPrice, quantity);
      order = await _calcCart(localCartItems);
      notifyListeners();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future clearCart() async {
    localCartItems.clear();
    order = OrderModel(orderDetails: []);
    count = 0;
    await _removeLocalCart();
    notifyListeners();
  }

  Future resetData() async {
    localCartItems.clear();
    order = OrderModel(orderDetails: []);
    count = 0;
    await _removeLocalCart();
    notifyListeners();
  }

  Future loadLocalCart() async {
    localCartItems = await _getLocalCart();
    count = localCartItems.length;
    notifyListeners();
  }

  List<LocalCartItem> _setToLocalCart(
      int productId, int merchantId, double singleFinalPrice, int quantity) {
    if (quantity > 0) {
      LocalCartItem? item =
          _findInLocalCart(localCartItems, productId, merchantId);
      if (item == null) {
        item = LocalCartItem(
            productId: productId,
            merchantId: merchantId,
            singleFinalPrice: singleFinalPrice,
            quantity: quantity);
        localCartItems.add(item);
      }
      item.singleFinalPrice = singleFinalPrice;
      item.quantity = quantity;
    } else {
      localCartItems.removeWhere((element) => element.productId == productId);
    }
    count = localCartItems.length;
    _saveLocalItems(localCartItems);
    return localCartItems;
  }

  Future<List<LocalCartItem>> _getLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    List<LocalCartItem> cartItem = [];
    if (prefs.containsKey(cartKey)) {
      cartItem = LocalCartItem.decode(prefs.getString(cartKey) ?? '[]');
    }
    return cartItem;
  }

  Future _saveLocalItems(List<LocalCartItem> cartItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cartKey, LocalCartItem.encode(cartItems));
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  Future _removeLocalCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cartKey);
    } catch (e) {
      debugPrint('Error removing cart: $e');
    }
  }

  LocalCartItem? _findInLocalCart(
      List<LocalCartItem> cartItems, int productId, int merchantId) {
    for (final item in cartItems) {
      if (item.productId == productId) {
        return item;
      }
    }
    return null;
  }
}
