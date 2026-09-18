export interface CaptainSettlementSummary {
  captainUserId: string;
  captainName: string;
  phoneNumber?: string;
  cashFloatBalance: number;
  wagesEarnedBalance: number;
  expectedNetCashDue: number;
  currency: string;
  lastSettlementDate?: string;
  totalDeliveredOrders: number;
}

export interface SettleCaptainShiftRequest {
  captainUserId: string;
  physicalCashReceived: number;
  currency?: string;
  notes?: string;
  discrepancyReason?: string;
}

export interface SettlementResult {
  settlementBatchId: string;
  batchCode: string;
  settlementTransactionId: string;
  transactionNumber: string;
  captainUserId: string;
  captainName: string;
  totalCashCollected: number;
  totalWagesEarned: number;
  expectedNetCash: number;
  physicalCashReceived: number;
  discrepancyAmount: number;
  discrepancyReason?: string;
  notes?: string;
  settledAt: string;
}

export interface AccountStatementItem {
  entryId: number;
  transactionId: string;
  transactionNumber: string;
  postedDate: string;
  referenceType: string;
  referenceId: string;
  debit: number;
  credit: number;
  runningBalance: number;
  currency: string;
  memo: string;
}

export interface CaptainShiftDetails {
  captainUserId: string;
  captainName: string;
  cashFloatBalance: number;
  wagesEarnedBalance: number;
  expectedNetCashDue: number;
  currency: string;
  lastSettlementDate?: string;
  floatStatement: AccountStatementItem[];
  earningsStatement: AccountStatementItem[];
}

export interface DailySettlementBatch {
  id: string;
  batchCode: string;
  captainUserId: string;
  captainName: string;
  batchDate: string;
  totalCashCollected: number;
  totalWagesEarned: number;
  netCashRemitted: number;
  discrepancyAmount: number;
  discrepancyReason?: string;
  handledByAdminId: string;
  settlementTransactionId: string;
  isLocked: boolean;
  notes?: string;
  createdDate: string;
}

export enum SettlementPartyType {
  Captain = 0,
  Merchant = 1,
}

export enum SettlementRequestStatus {
  Pending = 0,
  Approved = 1,
  Rejected = 2,
  Completed = 3,
}

export interface SettlementRequestItem {
  id: string;
  requestNumber: string;
  partyType: SettlementPartyType;
  status: SettlementRequestStatus;
  requestedByUserId: string;
  requestedByName: string;
  requestedByPhone?: string;
  amount: number;
  currency: string;
  method?: string;
  accountDetails?: string;
  notes?: string;
  rejectionReason?: string;
  reviewedAt?: string;
  completedAt?: string;
  createdDate: string;
  merchantAllocations: Array<{ merchantId: number; merchantTitle?: string; amount: number }>;
}

export interface MerchantReconciliationSummary {
  totalMerchantPayables: number;
  totalGrossPayable?: number;
  totalReservedSettlements: number;
  totalReservedForSettlement?: number;
  totalAvailableForSettlement: number;
  totalJTakCommission: number;
  totalJTakCommissionShare?: number;
  totalCompletedSettlements: number;
  activeMerchantsCount: number;
  pendingRequestsCount?: number;
  pendingSettlementRequestsCount?: number;
  currency: string;
}

export interface MerchantReconciliationItem {
  merchantId: number;
  merchantName: string;
  merchantTitle?: string;
  ownerName?: string;
  phone?: string;
  ordersCount: number;
  totalOrdersCount?: number;
  grossSales: number;
  grossSalesAmount?: number;
  jTakShare: number;
  jTakShareAmount?: number;
  merchantNet: number;
  merchantNetAmount?: number;
  reservedAmount: number;
  reservedSettlementAmount?: number;
  availableAmount: number;
  availableSettlementAmount?: number;
  approvedAwaitingReceiptAmount: number;
  approvedAwaitingPayoutAmount?: number;
  currentBalance: number;
  currentVendorPayableBalance?: number;
  lastSettlementDate?: string;
  lastSettlementStatus?: string;
  lastSettlementRequestNumber?: string;
  hasActiveSettlementLock?: boolean;
  currency: string;
}

export interface MerchantReconciliationDataTableRequest {
  page?: number;
  pageNumber?: number;
  pageSize?: number;
  searchTerm?: string;
  search?: string;
  sortColumn?: string;
  sortDirection?: string;
}

export interface MerchantReconciliationDataTableResult {
  items: MerchantReconciliationItem[];
  totalRecords: number;
  page?: number;
  pageNumber?: number;
  pageSize: number;
}

export interface MerchantStatementTransaction {
  entryId: number;
  transactionId: string;
  transactionNumber: string;
  postedDate: string;
  type: string;
  orderNumber?: number;
  merchantTitle?: string;
  customerName?: string;
  customerPhone?: string;
  orderDate?: string;
  grossAmount?: number;
  jTakShare?: number;
  merchantNet?: number;
  discount?: number;
  deliveryFee?: number;
  paymentMethod?: string;
  financialStatus?: string;
  debit: number;
  credit: number;
  runningBalance: number;
  currency: string;
  description: string;
  settlementRequestNumber?: string;
  referenceType?: string;
  referenceId?: string;
}

export interface MerchantSettlementHistoryItem {
  id: string;
  requestNumber: string;
  amount: number;
  currency: string;
  method?: string;
  accountDetails?: string;
  requestedAt: string;
  status: SettlementRequestStatus;
  approvedAt?: string;
  rejectedAt?: string;
  rejectionReason?: string;
  completedAt?: string;
  payoutSourceAccount?: string;
  approvedBy?: string;
  confirmedBy?: string;
  notes?: string;
}

export interface MerchantStatement {
  merchantId: number;
  merchantName: string;
  merchantTitle?: string;
  ownerName?: string;
  phone?: string;
  accountCode: string;
  currency: string;
  currentBalance: number;
  reservedAmount: number;
  availableAmount: number;
  approvedAwaitingReceiptAmount: number;
  totalRecords?: number;
  page?: number;
  pageSize?: number;
  items: MerchantStatementTransaction[];
  transactions?: MerchantStatementTransaction[];
  settlementHistory: MerchantSettlementHistoryItem[];
}

export enum SettlementHistoryPartyFilter {
  All = 0,
  Merchant = 1,
  Captain = 2,
}

export interface SettlementHistoryItem {
  id: string;
  requestNumber: string;
  partyType: SettlementPartyType;
  partyTypeLabel: string;
  partyName: string;
  phone?: string;
  merchantId?: number;
  driverId?: string;
  amount: number;
  currency: string;
  method?: string;
  status: string;
  requestedAt?: string;
  approvedAt?: string;
  completedAt: string;
  approvedBy?: string;
  confirmedBy?: string;
  sourceAccount?: string;
  destinationAccount?: string;
  journalTransactionNumber?: string;
  journalTransactionId?: string;
  notes?: string;
  operationType?: string;
}

export interface SettlementHistorySummary {
  totalCompletedCount: number;
  totalCompletedAmount: number;
  merchantCompletedCount: number;
  merchantCompletedAmount: number;
  driverCompletedCount: number;
  driverCompletedAmount: number;
  currency: string;
}

export interface SettlementHistoryDataTableRequest {
  searchTerm?: string;
  partyFilter: SettlementHistoryPartyFilter;
  fromDate?: string;
  toDate?: string;
  page: number;
  pageSize: number;
  sortColumn?: string;
  sortDirection?: string;
}

export interface SettlementHistoryDataTableResult {
  items: SettlementHistoryItem[];
  totalRecords: number;
  page: number;
  pageSize: number;
  summary: SettlementHistorySummary;
}

export interface SettlementReceipt {
  id: string;
  receiptNumber: string;
  requestNumber: string;
  partyType: SettlementPartyType;
  receiptTitle: string;
  partyName: string;
  phone?: string;
  merchantId?: number;
  driverId?: string;
  amount: number;
  currency: string;
  method?: string;
  status: string;
  requestedAt?: string;
  approvedAt?: string;
  completedAt: string;
  approvedBy?: string;
  confirmedBy?: string;
  vendorPayableAccount?: string;
  captainCashFloatAccount?: string;
  payoutSourceAccount?: string;
  destinationAccount?: string;
  journalTransactionNumber?: string;
  journalTransactionId?: string;
  operationType?: string;
  notes?: string;
  generatedAt: string;
}
