export enum SupportMessageStatus {
  New = 0,
  Read = 1,
  Resolved = 2,
}

export enum ErrandStatus {
  Submitted = 0,
  Quoted = 1,
  Approved = 2,
  Assigned = 3,
  Purchased = 4,
  Delivered = 5,
  Declined = 6,
  Cancelled = 7,
  PurchasePending = 8,
  DeliveryPending = 9,
  ReturnPending = 10,
  Returned = 11,
  Unavailable = 12,
}

export interface SupportMessage {
  id: number;
  userId?: string;
  senderName: string;
  senderPhone?: string;
  senderEmail?: string;
  title: string;
  message: string;
  status: SupportMessageStatus;
  adminNotes?: string;
  createdDate: string;
  resolvedDate?: string;
  errandStatus?: ErrandStatus;
  errandItemPrice?: number;
  errandDeliveryFee?: number;
  errandDriverEarning?: number;
  errandQuoteExpiresAt?: string;
  errandDriverUserId?: string;
  errandPurchaseCost?: number;
  errandReceiptReference?: string;
  errandReceiptPhotoToken?: string;
  errandCashCollected?: number;
  errandRefundAmount?: number;
  errandReturnReason?: string;
  errandUnavailableReason?: string;
  errandDeliveryCodeFailedAttempts?: number;
  errandLatestException?: string;
}

export interface ErrandDriver {
  id: string;
  name: string;
  maxCashFloat: number;
  availableCashFloat?: number;
  activeDeliveryOrders?: number;
  activePurchaseRequests?: number;
}

export interface SupportMessageStats {
  totalCount: number;
  newCount: number;
  inProgressCount: number;
  resolvedCount: number;
}

export interface ErrandQueuePage {
  items: SupportMessage[];
  totalCount: number;
}

export interface ErrandQueueStats {
  new: number;
  approved: number;
  quoted: number;
  inProgress: number;
  closed: number;
}
