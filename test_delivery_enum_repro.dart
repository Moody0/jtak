// Empirical verification script for Delivery App enum 7 parsing crash
enum OrderDetailsStatus { pending, merchantAccepted, shipping, delivered, merchantRejected, customerPending, customerCanceled }

extension ParseEnumExtention on int {
  OrderDetailsStatus get parseOrderDetailsStatus {
    switch (this) {
      case 0:
        return OrderDetailsStatus.pending;
      case 1:
        return OrderDetailsStatus.merchantAccepted;
      case 2:
        return OrderDetailsStatus.shipping;
      case 3:
        return OrderDetailsStatus.delivered;
      case 4:
        return OrderDetailsStatus.merchantRejected;
      case 5:
        return OrderDetailsStatus.customerPending;
      case 6:
        return OrderDetailsStatus.customerCanceled;
      default:
        throw Exception('order details status not recognized');
    }
  }
}

void main() {
  print('=== EMPIRICAL TEST: Delivery App Enum Parsing ===');
  for (int i = 0; i <= 6; i++) {
    print('Input code $i -> Success: ${i.parseOrderDetailsStatus.name}');
  }
  
  print('\nAttempting to parse status code 7 (OrderDetailStatus.DeliveryCanceled from backend)...');
  try {
    final status = 7.parseOrderDetailsStatus;
    print('Parsed unexpectedly: $status');
  } catch (e, stack) {
    print('>>> CONFIRMED DEFECT: Exception thrown when parsing value 7:');
    print('Error message: $e');
    print('Stack trace:');
    print(stack);
  }
}
