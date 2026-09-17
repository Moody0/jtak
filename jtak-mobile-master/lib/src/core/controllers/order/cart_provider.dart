import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jtek_app/src/core/controllers/order/order_payment_provider.dart';
import 'package:jtek_app/src/core/controllers/order/order_provider.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/enums/order_details_status_enum.dart';
import 'package:jtek_app/src/core/models/order/local_cart_item.dart';
import 'package:jtek_app/src/core/models/order/order_details_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/constants/shard_preference_kay.dart';
import '../../../utils/providers/custom_exception.dart';
import '../../../utils/providers/sol_api.dart';
import '../catalog/markets_provider.dart';
import '../../data/mock_catalog_data.dart';
import '../../enums/viewstate.dart';
import '../../enums/order_status_enum.dart';
import '../../models/order/order_model.dart';
import '../../services/authentication_service.dart';
import '../../services/locator.dart';
import '../app/base_provider.dart';
import 'cart_info.dart';

class MerchantMinOrderViolation {
  final int merchantId;
  final String merchantName;
  final double currentSubtotal;
  final int minOrder;
  final double remaining;

  const MerchantMinOrderViolation({
    required this.merchantId,
    required this.merchantName,
    required this.currentSubtotal,
    required this.minOrder,
    required this.remaining,
  });
}

class CartProvider extends BaseProvider<OrderModel> {
  final SolApi _api = locator<SolApi>();
  CartInfo cartInfo = CartInfo();
  OrderPaymentProvider orderPayment = OrderPaymentProvider();
  OrderModel order = OrderModel(orderDetails: []);
  List<LocalCartItem> localCartItems = [];

  int count = 0;

  int get totalQuantity {
    return localCartItems.length;
  }

  int get totalUnits {
    return localCartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    if (order.price != null && order.price! > 0) {
      return order.price!;
    }
    return localCartItems.fold(0.0, (sum, item) {
      return sum + (item.singleFinalPrice * item.quantity);
    });
  }

  List<OrderDetailsModel> get effectiveOrderDetails {
    if (order.orderDetails != null && order.orderDetails!.isNotEmpty) {
      return order.orderDetails!;
    }
    if (localCartItems.isEmpty) return [];
    return _buildFallbackDetails(localCartItems);
  }

  List<OrderDetailsModel> _buildFallbackDetails(List<LocalCartItem> items) {
    return items.map((item) {
      String storeTitle = 'متجر جيتك';
      if (locator.isRegistered<MarketsProvider>()) {
        final prov = locator<MarketsProvider>();
        final mStore =
            prov.markets.where((m) => m.id == item.merchantId).firstOrNull;
        if (mStore != null && mStore.name.isNotEmpty) {
          storeTitle = mStore.name;
        } else {
          final rStore = prov.restaurants
              .where((r) => r.id == item.merchantId)
              .firstOrNull;
          if (rStore != null && rStore.name.isNotEmpty) {
            storeTitle = rStore.name;
          }
        }
      }

      final mock = MockCatalogData.getMenuItemById(item.productId);
      if (storeTitle == 'متجر جيتك' &&
          mock?.restaurantName != null &&
          mock!.restaurantName.isNotEmpty) {
        storeTitle = mock.restaurantName;
      }

      final String resolvedTitle = (item.productTitle != null && item.productTitle!.trim().isNotEmpty)
          ? item.productTitle!
          : (mock?.title ?? 'منتج #${item.productId}');

      final String resolvedImage = (item.productImage != null && item.productImage!.trim().isNotEmpty)
          ? item.productImage!
          : (mock?.imageUrl ?? '');

      return OrderDetailsModel(
        productId: item.productId,
        merchantId: item.merchantId,
        merchantTitle: storeTitle,
        productTitle: resolvedTitle,
        singlePrice: item.singleFinalPrice,
        singleFinalPrice: item.singleFinalPrice,
        quantity: item.quantity,
        totalPrice: item.singleFinalPrice * item.quantity,
        totalFinalPrice: item.singleFinalPrice * item.quantity,
        productImage: resolvedImage,
        orderDetailStatus: OrderDetailsStatus.pending,
      );
    }).toList();
  }

  OrderModel _buildFallbackOrder(List<LocalCartItem> items) {
    final double itemsTotal = items.fold(
        0.0, (s, i) => s + (i.singleFinalPrice * i.quantity));
    return OrderModel(
      orderDetails: _buildFallbackDetails(items),
      price: itemsTotal,
    );
  }

  int? get currentMerchantId {
    if (localCartItems.isEmpty) return null;
    return localCartItems.first.merchantId;
  }

  List<int> get merchantIds {
    return localCartItems
        .map((item) => item.merchantId)
        .where((id) => id > 0)
        .toSet()
        .toList();
  }

  bool get isMultiMerchant => merchantIds.length > 1;

  double getSubtotalForMerchant(int merchantId) {
    return localCartItems
        .where((item) => item.merchantId == merchantId)
        .fold(0.0, (sum, item) {
      return sum + (item.singleFinalPrice * item.quantity);
    });
  }

  int getMinOrderForMerchant(int merchantId) {
    if (merchantId <= 0) return 0;
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final mStore = prov.markets.where((m) => m.id == merchantId).firstOrNull;
      if (mStore != null && mStore.minOrderAmount > 0) return mStore.minOrderAmount;
      final rStore = prov.restaurants.where((r) => r.id == merchantId).firstOrNull;
      if (rStore != null && rStore.minOrderAmount > 0) return rStore.minOrderAmount;
    }
    try {
      final rest = MockCatalogData.getRestaurantById(merchantId);
      return rest.minOrder;
    } catch (_) {}
    return 0;
  }

  String getMerchantTitle(int merchantId) {
    final detail =
        effectiveOrderDetails.where((i) => i.merchantId == merchantId).firstOrNull;
    if (detail?.merchantTitle != null && detail!.merchantTitle!.trim().isNotEmpty) {
      return detail.merchantTitle!.trim();
    }
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final mStore = prov.markets.where((m) => m.id == merchantId).firstOrNull;
      if (mStore != null && mStore.name.trim().isNotEmpty) return mStore.name.trim();
      final rStore = prov.restaurants.where((r) => r.id == merchantId).firstOrNull;
      if (rStore != null && rStore.name.trim().isNotEmpty) return rStore.name.trim();
    }
    try {
      final rest = MockCatalogData.getRestaurantById(merchantId);
      if (rest.name.trim().isNotEmpty) return rest.name.trim();
    } catch (_) {}
    return 'المتجر';
  }

  List<MerchantMinOrderViolation> get minOrderViolations {
    if (localCartItems.isEmpty) return const [];
    final violations = <MerchantMinOrderViolation>[];
    for (final mId in merchantIds) {
      final minOrder = getMinOrderForMerchant(mId);
      if (minOrder > 0) {
        final subtotal = getSubtotalForMerchant(mId);
        if (subtotal < minOrder) {
          violations.add(MerchantMinOrderViolation(
            merchantId: mId,
            merchantName: getMerchantTitle(mId),
            currentSubtotal: subtotal,
            minOrder: minOrder,
            remaining: (minOrder - subtotal).clamp(0.0, double.infinity),
          ));
        }
      }
    }
    return violations;
  }

  bool get reachesAllMinOrders => minOrderViolations.isEmpty;

  MerchantMinOrderViolation? get primaryMinOrderViolation =>
      minOrderViolations.firstOrNull;

  int get currentMerchantMinOrder {
    if (localCartItems.isEmpty) return 0;
    if (minOrderViolations.isNotEmpty) {
      return minOrderViolations.first.minOrder;
    }
    final mId = currentMerchantId;
    if (mId != null && mId > 0) {
      return getMinOrderForMerchant(mId);
    }
    return 0;
  }

  double get deliveryFee {
    if (localCartItems.isEmpty) return 0.0;
    final mIds = merchantIds;
    if (mIds.isEmpty) return 5000.0;

    double baseFee = 5000.0;
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final firstMid = mIds.first;
      final mStore = prov.markets.where((m) => m.id == firstMid).firstOrNull;
      if (mStore != null && mStore.deliveryFeeAmount > 0) {
        baseFee = mStore.deliveryFeeAmount.toDouble();
      } else {
        final rStore = prov.restaurants.where((r) => r.id == firstMid).firstOrNull;
        if (rStore != null && rStore.deliveryFeeAmount > 0) {
          baseFee = rStore.deliveryFeeAmount.toDouble();
        }
      }
    }
    if (mIds.length > 1) {
      return baseFee + (2500.0 * (mIds.length - 1));
    }
    return baseFee;
  }

  String get currentMerchantName {
    if (localCartItems.isEmpty) return '';
    final mIds = merchantIds;
    if (mIds.length > 1) {
      return 'عدة متاجر (${mIds.length})';
    }
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

  /// Returns whether a merchant ID represents a Restaurant (kind = 0).
  bool isRestaurantMerchant(int merchantId, {int? merchantKind}) {
    if (merchantKind != null) {
      return merchantKind == 0;
    }
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      if (prov.restaurants.any((r) => r.id == merchantId)) {
        return true;
      }
      if (prov.markets.any((m) => m.id == merchantId)) {
        return false;
      }
    }
    try {
      final r = MockCatalogData.getRestaurantById(merchantId);
      if (r.id == merchantId) {
        return !r.isMarket;
      }
    } catch (_) {}
    if (merchantId >= 1 && merchantId <= 11) {
      return true;
    }
    return false;
  }

  /// Returns whether a merchant ID represents a Market/Store/Grocery (kind != 0).
  bool isMarketMerchant(int merchantId, {int? merchantKind}) {
    return !isRestaurantMerchant(merchantId, merchantKind: merchantKind);
  }

  /// Distinct Restaurant IDs currently present in the cart.
  List<int> get restaurantIdsInCart {
    return localCartItems
        .where((item) => isRestaurantMerchant(item.merchantId))
        .map((item) => item.merchantId)
        .toSet()
        .toList();
  }

  /// Distinct Market IDs currently present in the cart.
  List<int> get marketIdsInCart {
    return localCartItems
        .where((item) => isMarketMerchant(item.merchantId))
        .map((item) => item.merchantId)
        .toSet()
        .toList();
  }

  /// Validates whether adding an item from [newMerchantId] would violate
  /// the rule: At most 1 Restaurant AND at most 1 Market per order.
  bool isDifferentMerchant(int newMerchantId, {int? merchantKind}) {
    if (localCartItems.isEmpty) return false;

    final isNewRest = isRestaurantMerchant(newMerchantId, merchantKind: merchantKind);
    if (isNewRest) {
      final restIds = restaurantIdsInCart;
      // If there is already a restaurant in cart, and it is different from newMerchantId -> conflict!
      if (restIds.isNotEmpty && !restIds.contains(newMerchantId)) {
        return true;
      }
    } else {
      final marketIds = marketIdsInCart;
      // If there is already a market in cart, and it is different from newMerchantId -> conflict!
      if (marketIds.isNotEmpty && !marketIds.contains(newMerchantId)) {
        return true;
      }
    }

    return false;
  }

  /// Resolves the human-friendly name of the conflicting store in the active cart.
  String getConflictingMerchantName(int newMerchantId, {int? merchantKind}) {
    final isNewRest = isRestaurantMerchant(newMerchantId, merchantKind: merchantKind);
    final conflictingIds = isNewRest ? restaurantIdsInCart : marketIdsInCart;
    if (conflictingIds.isEmpty) {
      return currentMerchantName;
    }

    final targetMid = conflictingIds.first;
    if (locator.isRegistered<MarketsProvider>()) {
      final prov = locator<MarketsProvider>();
      final rStore = prov.restaurants.where((r) => r.id == targetMid).firstOrNull;
      if (rStore != null && rStore.name.isNotEmpty) return rStore.name.split(' - ').first;
      final mStore = prov.markets.where((m) => m.id == targetMid).firstOrNull;
      if (mStore != null && mStore.name.isNotEmpty) return mStore.name.split(' - ').first;
    }

    try {
      final rest = MockCatalogData.getRestaurantById(targetMid);
      if (rest.name.isNotEmpty) return rest.name.split(' - ').first;
    } catch (_) {}

    return isNewRest ? 'المطعم السابق' : 'الماركت السابق';
  }

  Future<void> replaceCartWithItem(int productId, int merchantId,
      double singleFinalPrice, int quantity,
      {String? title, String? imageUrl}) async {
    final bool isNewRest = isRestaurantMerchant(merchantId);

    // Remove only items from the conflicting merchant category (restaurants or markets)
    // preserving valid items from the other category (1 restaurant + 1 market supported)
    localCartItems.removeWhere((item) {
      final bool isItemRest = isRestaurantMerchant(item.merchantId);
      return isItemRest == isNewRest;
    });

    order = OrderModel(orderDetails: []);
    count = localCartItems.length;
    await _saveLocalItems(localCartItems);
    await setToCart(productId, merchantId, singleFinalPrice, quantity,
        title: title, imageUrl: imageUrl);
  }

  int getProductQuantity(int? productId, [int? merchantId]) {
    if (productId == null) return 0;
    for (final item in localCartItems) {
      if (item.productId == productId &&
          (merchantId == null || merchantId <= 0 || item.merchantId == merchantId)) {
        return item.quantity;
      }
    }
    return 0;
  }

  Future<OrderModel?> submitOrder() async {
    if (state == ViewState.busy) {
      debugPrint('CartProvider.submitOrder: Submission already in flight, ignoring duplicate call.');
      return null;
    }
    if (!reachesAllMinOrders) {
      final v = primaryMinOrderViolation;
      final storeName = v?.merchantName ?? 'المتجر';
      final minAmt = v?.minOrder ?? 0;
      throw Exception('الحد الأدنى للطلب من «$storeName» هو $minAmt ل.س');
    }
    try {
      setState(ViewState.busy);
      var cartItems = _getCartJsonBody(localCartItems);

      // Clean & Sanitize Phone Number to valid E.164 format (+9639...)
      String rawPhone = cartInfo.phoneNumber?.phoneNumber ??
          locator<AuthenticationService>().user?.phoneNumber ??
          '';
      if (rawPhone.isEmpty) {
        await locator<AuthenticationService>().getAuthorizationData();
        await cartInfo.initData();
        rawPhone = cartInfo.phoneNumber?.phoneNumber ??
            locator<AuthenticationService>().user?.phoneNumber ??
            '';
      }
      if (rawPhone.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(AuthenticationService.kUserProfileKey)) {
          final raw = prefs.getString(AuthenticationService.kUserProfileKey);
          if (raw != null && raw.isNotEmpty) {
            try {
              final map = json.decode(raw);
              rawPhone = map['phoneNumber'] ?? '';
            } catch (_) {}
          }
        }
      }
      String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.isEmpty) {
        throw Exception('يرجى تحديد رقم الهاتف في ملفك الشخصي لإتمام الطلب.');
      }

      if (cleanPhone.startsWith('00')) {
        cleanPhone = '+${cleanPhone.substring(2)}';
      } else if (cleanPhone.startsWith('09') && cleanPhone.length == 10) {
        cleanPhone = '+963${cleanPhone.substring(1)}';
      } else if (cleanPhone.startsWith('0') && cleanPhone.length >= 9) {
        cleanPhone = '+963${cleanPhone.substring(1)}';
      } else if (cleanPhone.startsWith('9') && cleanPhone.length == 9) {
        cleanPhone = '+963$cleanPhone';
      } else if (cleanPhone.startsWith('963') && !cleanPhone.startsWith('+')) {
        cleanPhone = '+$cleanPhone';
      } else if (!cleanPhone.startsWith('+') && cleanPhone.isNotEmpty) {
        cleanPhone = '+$cleanPhone';
      }

      // Ensure we have a genuine, validated OpenIddict token before calling SubmitOrder
      await locator<AuthenticationService>().ensureValidAccessToken(cleanPhone);

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

      final String rawName = cartInfo.name ??
          locator<AuthenticationService>().user?.fullName ??
          'عميل جيتك';
      final String safeName =
          rawName.trim().isNotEmpty ? rawName.trim() : 'عميل جيتك';

      Map<String, dynamic> body = {
        "cartItems": cartItems,
        "phonenumber": cleanPhone,
        "lat": lat,
        "lng": lng,
        "name": safeName,
        "address": address,
        "paymentMethod": orderPayment.paymentMethod.index,
        "idempotencyKey": idempotencyKey,
      };

      dynamic response;
      try {
        response = await _api.postRequest('/Cart/SubmitOrder', body);
      } catch (submitErr) {
        if (submitErr is UnauthorisedException) {
          debugPrint('SubmitOrder received 401. Attempting automatic token renewal and retry...');
          final renewed = await locator<AuthenticationService>().renewToken(cleanPhone);
          if (renewed) {
            response = await _api.postRequest('/Cart/SubmitOrder', body);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
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
                  .map((d) {
                    final local = localCartItems.where((l) => l.productId == d.productId).firstOrNull;
                    final mock = MockCatalogData.getMenuItemById(d.productId ?? 0);
                    final resolvedImg = (d.productImage != null && d.productImage!.trim().isNotEmpty)
                        ? d.productImage!
                        : (local?.productImage?.isNotEmpty == true ? local!.productImage! : (mock?.imageUrl ?? ''));
                    final resolvedTitle = (d.productTitle != null && d.productTitle!.trim().isNotEmpty)
                        ? d.productTitle!
                        : (local?.productTitle?.isNotEmpty == true ? local!.productTitle! : (mock?.title ?? 'وجبة خاصة'));
                    return OrderDetailsModel(
                        productId: d.productId,
                        merchantId: d.merchantId,
                        merchantTitle: d.merchantTitle,
                        productTitle: resolvedTitle,
                        singlePrice: d.singlePrice,
                        singleFinalPrice: d.singleFinalPrice,
                        quantity: d.quantity,
                        totalPrice: d.totalPrice,
                        totalFinalPrice: d.totalFinalPrice,
                        productImage: resolvedImg,
                        orderDetailStatus:
                            d.orderDetailStatus ?? OrderDetailsStatus.pending,
                      );
                  })
                  .toList()
              : localCartItems.map((item) {
                  final mock = MockCatalogData.getMenuItemById(item.productId);
                  return OrderDetailsModel(
                    productId: item.productId,
                    merchantId: item.merchantId,
                    merchantTitle: mock?.restaurantName ?? 'متجر جيتك',
                    productTitle: item.productTitle?.isNotEmpty == true ? item.productTitle! : (mock?.title ?? 'وجبة خاصة'),
                    singlePrice: item.singleFinalPrice,
                    singleFinalPrice: item.singleFinalPrice,
                    quantity: item.quantity,
                    totalPrice: item.singleFinalPrice * item.quantity,
                    totalFinalPrice: item.singleFinalPrice * item.quantity,
                    productImage: item.productImage?.isNotEmpty == true ? item.productImage! : (mock?.imageUrl ?? ''),
                    orderDetailStatus: OrderDetailsStatus.pending,
                  );
                }).toList();

      final storeTitles = details
          .map((d) => d.merchantTitle)
          .where((t) => t != null && t.isNotEmpty)
          .toSet()
          .toList();
      final String orderDescription = storeTitles.isNotEmpty
          ? storeTitles.join(' + ')
          : 'متجر جيتك';

      final placedOrder = OrderModel(
        id: newOrderId,
        purchaseDate: DateTime.now().toIso8601String(),
        price: finalTotal,
        phonenumber: cleanPhone,
        address: address,
        user: safeName,
        paymentMethod: orderPayment.paymentMethod,
        orderStatus: OrderStatus.pending,
        description: orderDescription,
        deliveryOtp: order.deliveryOtp,
        orderDetails: details,
      );

      await OrderProvider.saveNewOrderGlobally(placedOrder);

      await resetData();
      setState(ViewState.idle);
      return placedOrder;
    } catch (err) {
      setState(ViewState.idle);
      debugPrint('SubmitOrder error: $err');
      if (err is CustomException && err.data != null) {
        try {
          final Map<String, dynamic> raw = (err.data is Map)
              ? Map<String, dynamic>.from(err.data as Map)
              : {};
          final orderMap = (raw['order'] is Map)
              ? Map<String, dynamic>.from(raw['order'] as Map)
              : raw;
          if (orderMap['orderDetails'] != null || orderMap['OrderDetails'] != null) {
            final returnedOrder = OrderModel.fromMap(orderMap);
            if (returnedOrder.orderDetails != null && returnedOrder.orderDetails!.isNotEmpty) {
              order = returnedOrder;
              notifyListeners();
            }
          }
        } catch (syncErr) {
          debugPrint('Failed to sync returned order warnings: $syncErr');
        }
      }
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
        if (order.orderDetails == null || order.orderDetails!.isEmpty) {
          order = _buildFallbackOrder(localCartItems);
        }
        try {
          final remoteOrder = await _calcCart(localCartItems);
          if (remoteOrder.orderDetails != null &&
              remoteOrder.orderDetails!.isNotEmpty) {
            _enrichOrderDetails(remoteOrder);
            order = remoteOrder;
          }
        } catch (calcErr) {
          debugPrint(
              'Backend _calcCart failed, retained local fallback order: $calcErr');
        }
      } else {
        order = OrderModel(orderDetails: []);
      }
      setState(ViewState.idle);
    } catch (err) {
      if (localCartItems.isNotEmpty &&
          (order.orderDetails == null || order.orderDetails!.isEmpty)) {
        order = _buildFallbackOrder(localCartItems);
      }
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

  void _enrichOrderDetails(OrderModel o) {
    if (o.orderDetails == null) return;
    for (final d in o.orderDetails!) {
      final local = localCartItems.where((l) =>
          l.productId == d.productId &&
          (d.merchantId == null || d.merchantId == 0 || l.merchantId == d.merchantId)
      ).firstOrNull;
      final mock = MockCatalogData.getMenuItemById(d.productId ?? 0);
      if (d.productImage == null || d.productImage!.trim().isEmpty) {
        d.productImage = (local?.productImage != null && local!.productImage!.trim().isNotEmpty)
            ? local.productImage
            : (mock?.imageUrl ?? '');
      }
      if (d.productTitle == null || d.productTitle!.trim().isEmpty) {
        d.productTitle = (local?.productTitle != null && local!.productTitle!.trim().isNotEmpty)
            ? local.productTitle
            : (mock?.title ?? 'وجبة خاصة');
      }
      if (local != null && local.singleFinalPrice > 0) {
        d.singleFinalPrice = local.singleFinalPrice;
        d.singlePrice = local.singleFinalPrice;
      }
    }
    final calculatedTotal = o.orderDetails!.where((x) =>
        x.orderDetailStatus != OrderDetailsStatus.merchantRejected &&
        x.orderDetailStatus != OrderDetailsStatus.customerCanceled &&
        x.orderDetailStatus != OrderDetailsStatus.deliveryCanceled
    ).fold<double>(0.0, (sum, x) => sum + ((x.singleFinalPrice ?? 0.0) * (x.quantity ?? 1)));
    if (calculatedTotal > 0 && (o.price == null || o.price! <= 0)) {
      o.price = calculatedTotal;
    }
  }

  Timer? _calcDebounceTimer;

  void _scheduleCalcCart() {
    _calcDebounceTimer?.cancel();
    _calcDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (localCartItems.isEmpty) return;
      try {
        final remoteOrder = await _calcCart(localCartItems);
        if (remoteOrder.orderDetails != null &&
            remoteOrder.orderDetails!.isNotEmpty) {
          _enrichOrderDetails(remoteOrder);
          order = remoteOrder;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Debounced _calcCart error: $e');
      }
    });
  }

  Future removeFromCart(int productId, int merchantId) async {
    try {
      _setToLocalCart(productId, merchantId, 0.0, 0);
      if (localCartItems.isEmpty) {
        order = OrderModel(orderDetails: []);
      } else {
        order = _buildFallbackOrder(localCartItems);
      }
      // Instant optimistic UI update
      notifyListeners();
      _scheduleCalcCart();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future addToCart(int productId, int merchantId, double singleFinalPrice,
      {int quantity = 1, String? title, String? imageUrl}) async {
    try {
      final current =
          _findInLocalCart(localCartItems, productId, merchantId)?.quantity ??
              0;
      _setToLocalCart(
          productId, merchantId, singleFinalPrice, current + quantity,
          title: title, imageUrl: imageUrl);
      // Instant optimistic UI update
      order = _buildFallbackOrder(localCartItems);
      notifyListeners();
      _scheduleCalcCart();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future setToCart(int productId, int merchantId, double singleFinalPrice,
      int quantity, {String? title, String? imageUrl}) async {
    try {
      _setToLocalCart(productId, merchantId, singleFinalPrice, quantity,
          title: title, imageUrl: imageUrl);
      // Instant optimistic UI update
      order = _buildFallbackOrder(localCartItems);
      notifyListeners();
      _scheduleCalcCart();
    } catch (err) {
      debugPrint(err.toString());
      notifyListeners();
    }
  }

  Future clearCart() async {
    _calcDebounceTimer?.cancel();
    localCartItems.clear();
    order = OrderModel(orderDetails: []);
    count = 0;
    await _removeLocalCart();
    notifyListeners();
  }

  Future resetData() async {
    _calcDebounceTimer?.cancel();
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
      int productId, int merchantId, double singleFinalPrice, int quantity,
      {String? title, String? imageUrl}) {
    if (quantity > 0) {
      LocalCartItem? item =
          _findInLocalCart(localCartItems, productId, merchantId);
      if (item == null) {
        item = LocalCartItem(
            productId: productId,
            merchantId: merchantId,
            singleFinalPrice: singleFinalPrice,
            quantity: quantity,
            productTitle: title,
            productImage: imageUrl);
        localCartItems.add(item);
      } else {
        item.singleFinalPrice = singleFinalPrice;
        item.quantity = quantity;
        if (title != null && title.trim().isNotEmpty) {
          item.productTitle = title;
        }
        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          item.productImage = imageUrl;
        }
      }
    } else {
      localCartItems.removeWhere((element) =>
          element.productId == productId && element.merchantId == merchantId);
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
      if (item.productId == productId && item.merchantId == merchantId) {
        return item;
      }
    }
    return null;
  }
}
