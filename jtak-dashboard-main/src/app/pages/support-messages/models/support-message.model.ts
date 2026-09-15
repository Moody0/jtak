export enum SupportMessageStatus {
  New = 0,
  Read = 1,
  Resolved = 2,
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
}

export interface SupportMessageStats {
  totalCount: number;
  newCount: number;
  inProgressCount: number;
  resolvedCount: number;
}
