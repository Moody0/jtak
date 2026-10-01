export interface DriverCashAdvanceDriver {
  id: string;
  name: string;
  balance: number;
  maxCashFloat: number;
  remainingCapacity: number;
}

export interface DriverCashAdvanceHistoryItem {
  transactionNumber: string;
  postedAt: string;
  driverUserId: string;
  driverName: string;
  amount: number;
  reference: string;
  description: string;
  reason: string;
}

export interface DriverCashAdvanceOverview {
  currency: string;
  companyVaultBalance: number;
  drivers: DriverCashAdvanceDriver[];
  recentAdvances: DriverCashAdvanceHistoryItem[];
}
