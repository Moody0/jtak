/// ---------------------------------------------------------------------------
/// JTAK Live Order Tracking & GPS Telemetry Models (Phase 4)
/// ---------------------------------------------------------------------------
library;

class ShippingStopProgressModel {
  final int index;
  final String? title;
  final bool isDarkStore;
  final bool isCompleted;
  final double lat;
  final double lng;
  final int stopType;

  ShippingStopProgressModel({
    required this.index,
    this.title,
    this.isDarkStore = false,
    this.isCompleted = false,
    required this.lat,
    required this.lng,
    this.stopType = 0,
  });

  factory ShippingStopProgressModel.fromMap(Map<String, dynamic> map) {
    return ShippingStopProgressModel(
      index: map['index'] is int
          ? map['index']
          : int.tryParse(map['index']?.toString() ?? '0') ?? 0,
      title: map['title']?.toString(),
      isDarkStore: map['isDarkStore'] == true,
      isCompleted: map['isCompleted'] == true,
      lat: (map['lat'] is num)
          ? (map['lat'] as num).toDouble()
          : double.tryParse(map['lat']?.toString() ?? '0') ?? 0.0,
      lng: (map['lng'] is num)
          ? (map['lng'] as num).toDouble()
          : double.tryParse(map['lng']?.toString() ?? '0') ?? 0.0,
      stopType: map['stopType'] is int
          ? map['stopType']
          : int.tryParse(map['stopType']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'title': title,
      'isDarkStore': isDarkStore,
      'isCompleted': isCompleted,
      'lat': lat,
      'lng': lng,
      'stopType': stopType,
    };
  }
}

class OrderLiveTrackModel {
  final int orderId;
  final int orderStatus;
  final String? driverId;
  final String? driverName;
  final String? driverPhoneNumber;
  final double? driverLat;
  final double? driverLng;
  final double? heading;
  final double? speed;
  final DateTime? locationUpdatedAt;
  final bool isLive;
  final int etaMinutes;
  final int remainingDistanceMeters;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;
  final int currentStopIndex;
  final String? currentStopTitle;
  final bool currentStopIsDarkStore;
  final String? deliveryOtp;
  final List<ShippingStopProgressModel> stops;

  OrderLiveTrackModel({
    required this.orderId,
    this.orderStatus = 0,
    this.driverId,
    this.driverName,
    this.driverPhoneNumber,
    this.driverLat,
    this.driverLng,
    this.heading,
    this.speed,
    this.locationUpdatedAt,
    this.isLive = false,
    this.etaMinutes = 0,
    this.remainingDistanceMeters = 0,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    this.currentStopIndex = 0,
    this.currentStopTitle,
    this.currentStopIsDarkStore = false,
    this.deliveryOtp,
    this.stops = const [],
  });

  factory OrderLiveTrackModel.fromMap(Map<String, dynamic> map) {
    List<ShippingStopProgressModel> parsedStops = [];
    if (map['stops'] is List) {
      for (var s in (map['stops'] as List)) {
        if (s is Map<String, dynamic>) {
          parsedStops.add(ShippingStopProgressModel.fromMap(s));
        } else if (s is Map) {
          parsedStops.add(ShippingStopProgressModel.fromMap(
              Map<String, dynamic>.from(s)));
        }
      }
    }

    DateTime? parsedUpdatedAt;
    if (map['locationUpdatedAt'] != null) {
      try {
        parsedUpdatedAt = DateTime.parse(map['locationUpdatedAt'].toString());
      } catch (_) {}
    }

    return OrderLiveTrackModel(
      orderId: map['orderId'] is int
          ? map['orderId']
          : int.tryParse(map['orderId']?.toString() ?? '0') ?? 0,
      orderStatus: map['orderStatus'] is int
          ? map['orderStatus']
          : int.tryParse(map['orderStatus']?.toString() ?? '0') ?? 0,
      driverId: map['driverId']?.toString(),
      driverName: map['driverName']?.toString(),
      driverPhoneNumber: map['driverPhoneNumber']?.toString(),
      driverLat: (map['driverLat'] is num)
          ? (map['driverLat'] as num).toDouble()
          : double.tryParse(map['driverLat']?.toString() ?? ''),
      driverLng: (map['driverLng'] is num)
          ? (map['driverLng'] as num).toDouble()
          : double.tryParse(map['driverLng']?.toString() ?? ''),
      heading: (map['heading'] is num)
          ? (map['heading'] as num).toDouble()
          : double.tryParse(map['heading']?.toString() ?? ''),
      speed: (map['speed'] is num)
          ? (map['speed'] as num).toDouble()
          : double.tryParse(map['speed']?.toString() ?? ''),
      locationUpdatedAt: parsedUpdatedAt,
      isLive: map['isLive'] == true,
      etaMinutes: map['etaMinutes'] is int
          ? map['etaMinutes']
          : int.tryParse(map['etaMinutes']?.toString() ?? '0') ?? 0,
      remainingDistanceMeters: map['remainingDistanceMeters'] is int
          ? map['remainingDistanceMeters']
          : int.tryParse(map['remainingDistanceMeters']?.toString() ?? '0') ?? 0,
      destinationLat: (map['destinationLat'] is num)
          ? (map['destinationLat'] as num).toDouble()
          : double.tryParse(map['destinationLat']?.toString() ?? ''),
      destinationLng: (map['destinationLng'] is num)
          ? (map['destinationLng'] as num).toDouble()
          : double.tryParse(map['destinationLng']?.toString() ?? ''),
      destinationAddress: map['destinationAddress']?.toString(),
      currentStopIndex: map['currentStopIndex'] is int
          ? map['currentStopIndex']
          : int.tryParse(map['currentStopIndex']?.toString() ?? '0') ?? 0,
      currentStopTitle: map['currentStopTitle']?.toString(),
      currentStopIsDarkStore: map['currentStopIsDarkStore'] == true,
      deliveryOtp: map['deliveryOtp']?.toString() ?? map['DeliveryOtp']?.toString(),
      stops: parsedStops,
    );
  }
}
