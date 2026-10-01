export interface CaptainSettlementsOverview {
  totalOrders: number;
  totalCashCollected: number;
  totalDeliveryFees: number;
  totalCaptainEarnings: number;
  totalNetDueToCompany: number;
  items: CaptainSettlementItem[];
}

export interface CaptainSettlementItem {
  captainId: string;
  captainName: string;
  phoneNumber?: string;
  compensationType: number; // 0: Salaried, 1: PerKm, 2: Percentage
  compensationTypeDisplay: string;
  captainRate: number;
  completedOrdersCount: number;
  totalCashCollected: number;
  totalDeliveryFees: number;
  totalCaptainEarnings: number;
  netDueToCompany: number;
  unsettledOrdersCount: number;
  settledOrdersCount: number;
  settlementStatus: 'Settled' | 'Unsettled' | 'NoOrders';
  lastSettledAt?: string;
  lastSettlementBatchId?: string;
}

export interface CaptainOrdersSettlementDetail {
  captainId: string;
  captainName: string;
  phoneNumber?: string;
  compensationType: number;
  compensationTypeDisplay: string;
  captainRate: number;
  totalOrders: number;
  totalCashCollected: number;
  totalDeliveryFees: number;
  totalCaptainEarnings: number;
  netDueToCompany: number;
  orders: CaptainOrderSettlementItem[];
}

export interface CaptainOrderSettlementItem {
  orderId: number;
  customerName: string;
  customerPhone?: string;
  deliveredAt?: string;
  distanceInKm?: number;
  customerDeliveryFee: number;
  originalDeliveryFee: number;
  captainEarning: number;
  cashCollected: number;
  productsTotal: number;
  paymentMethod: number;
  isSettled: boolean;
  settledAt?: string;
  settlementBatchId?: string;
}

export interface ConfirmCaptainSettlementRequest {
  captainId: string;
  orderIds?: number[];
  fromDate?: string;
  toDate?: string;
  notes?: string;
}

export interface SettlementBatchReceipt {
  batchId: string;
  captainId: string;
  captainName: string;
  phoneNumber?: string;
  compensationType: number;
  compensationTypeDisplay: string;
  settledAt: string;
  ordersCount: number;
  totalCashCollected: number;
  totalDeliveryFees: number;
  totalCaptainEarnings: number;
  netDueToCompany: number;
  handledByAdminName: string;
  notes?: string;
  orders: CaptainOrderSettlementItem[];
}

export interface CaptainLookupItem {
  id: string;
  name: string;
  phoneNumber?: string;
  compensationType: number;
  captainRate: number;
}
