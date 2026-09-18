export interface AdminAuditLog {
  id: string;
  createdDate: string;
  adminUserId?: string;
  adminName?: string;
  adminUserName?: string;
  adminEmail?: string;
  module: string;
  action: string;
  entityType?: string;
  entityId?: string;
  description?: string;
  result: string; // 'Success' | 'Failed'
  failureReason?: string;
  ipAddress?: string;
  userAgent?: string;
  correlationId?: string;
  beforeStateJson?: string;
  afterStateJson?: string;
}

export interface AdminAuditLogSummary {
  totalOperations: number;
  todayOperations: number;
  thisWeekOperations: number;
  successCount: number;
  failureCount: number;
  topModule: string;
  topAdmin: string;
}

export interface AdminAuditLogFilter {
  module?: string;
  action?: string;
  result?: string;
  adminUserId?: string;
  fromDate?: string;
  toDate?: string;
}
