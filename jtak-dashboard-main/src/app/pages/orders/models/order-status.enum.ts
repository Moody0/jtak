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
