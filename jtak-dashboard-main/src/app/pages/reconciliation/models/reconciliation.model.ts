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
