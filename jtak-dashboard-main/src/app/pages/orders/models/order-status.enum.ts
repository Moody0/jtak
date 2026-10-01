export enum OrderDetailStatus {
  Pending = 0,
  MerchantAccepted = 1,
  ShippingStarted = 2,
  Delivered = 3,
  MerchantRejected = 4,
  CustomerPending = 5,
  CustomerCanceled = 6,
  DeliveryCanceled = 7,
  ReadyForPickup = 8,
}

export enum AggregateOrderStatus {
  Draft = 0,
  Pending = 1,
  MerchantAccepted = 2,
  ReadyForPickup = 3,
  InTransit = 4,
  Delivered = 5,
  PartiallyDelivered = 6,
  CustomerCanceled = 7,
  DeliveryCanceled = 8,
  MerchantRejected = 9,
}

