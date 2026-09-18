import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import {
  CaptainSettlementSummary,
  CaptainShiftDetails,
  DailySettlementBatch,
  SettleCaptainShiftRequest,
  SettlementResult,
  SettlementRequestItem,
  MerchantReconciliationSummary,
  MerchantReconciliationItem,
  MerchantReconciliationDataTableRequest,
  MerchantReconciliationDataTableResult,
  MerchantStatement,
  SettlementHistoryDataTableRequest,
  SettlementHistoryDataTableResult,
  SettlementHistorySummary,
  SettlementReceipt,
  SettlementHistoryItem,
} from '../models/reconciliation.model';

@Injectable({
  providedIn: 'root',
})
export class ReconciliationService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/FleetReconciliation`;
  private readonly merchantBaseUrl = `${environment.apiUrl}/Admin/MerchantReconciliation`;
  private readonly historyBaseUrl = `${environment.apiUrl}/Admin/SettlementHistory`;

  constructor(private http: HttpClient) {}

  getMerchantSummary(): Observable<MerchantReconciliationSummary> {
    return this.http.get<MerchantReconciliationSummary>(`${this.merchantBaseUrl}/Summary`);
  }

  getMerchantReconciliationDataTable(params: MerchantReconciliationDataTableRequest): Observable<MerchantReconciliationDataTableResult> {
    return this.http.post<MerchantReconciliationDataTableResult>(`${this.merchantBaseUrl}/DataTable`, params);
  }

  getMerchantStatement(merchantId: number, search?: string, fromDate?: string, toDate?: string): Observable<MerchantStatement> {
    let url = `${this.merchantBaseUrl}/${merchantId}/Statement`;
    const queryParams: string[] = [];
    if (search && search.trim()) {
      queryParams.push(`search=${encodeURIComponent(search.trim())}`);
    }
    if (fromDate) {
      queryParams.push(`fromDate=${encodeURIComponent(fromDate)}`);
    }
    if (toDate) {
      queryParams.push(`toDate=${encodeURIComponent(toDate)}`);
    }
    if (queryParams.length > 0) {
      url += `?${queryParams.join('&')}`;
    }
    return this.http.get<MerchantStatement>(url);
  }

  getCaptains(): Observable<CaptainSettlementSummary[]> {
    return this.http.get<CaptainSettlementSummary[]>(`${this.baseUrl}/Captains`);
  }

  getCaptainStatement(captainId: string): Observable<CaptainShiftDetails> {
    return this.http.get<CaptainShiftDetails>(
      `${this.baseUrl}/Captain/${captainId}/Statement`
    );
  }

  settleShift(request: SettleCaptainShiftRequest): Observable<SettlementResult> {
    return this.http.post<SettlementResult>(`${this.baseUrl}/Settle`, request);
  }

  getHistory(count: number = 50): Observable<DailySettlementBatch[]> {
    return this.http.get<DailySettlementBatch[]>(
      `${this.baseUrl}/History?count=${count}`
    );
  }

  getSettlementHistoryDataTable(params: SettlementHistoryDataTableRequest): Observable<SettlementHistoryDataTableResult> {
    return this.http.post<SettlementHistoryDataTableResult>(`${this.historyBaseUrl}/DataTable`, params);
  }

  getSettlementHistorySummary(partyFilter?: number, fromDate?: string, toDate?: string, search?: string): Observable<SettlementHistorySummary> {
    let url = `${this.historyBaseUrl}/Summary`;
    const queryParams: string[] = [];
    if (partyFilter !== undefined && partyFilter !== null) {
      queryParams.push(`partyFilter=${partyFilter}`);
    }
    if (fromDate) {
      queryParams.push(`fromDate=${encodeURIComponent(fromDate)}`);
    }
    if (toDate) {
      queryParams.push(`toDate=${encodeURIComponent(toDate)}`);
    }
    if (search && search.trim()) {
      queryParams.push(`searchTerm=${encodeURIComponent(search.trim())}`);
    }
    if (queryParams.length > 0) {
      url += `?${queryParams.join('&')}`;
    }
    return this.http.get<SettlementHistorySummary>(url);
  }

  getSettlementReceipt(id: string): Observable<SettlementReceipt> {
    return this.http.get<SettlementReceipt>(`${this.historyBaseUrl}/${encodeURIComponent(id)}/Receipt`);
  }

  getSettlementHistoryPrintData(params: SettlementHistoryDataTableRequest): Observable<SettlementHistoryItem[]> {
    return this.http.post<SettlementHistoryItem[]>(`${this.historyBaseUrl}/PrintData`, params);
  }

  getSettlementRequests(): Observable<SettlementRequestItem[]> {
    return this.http.get<SettlementRequestItem[]>(`${environment.apiUrl}/Admin/SettlementRequests`);
  }

  acceptRequest(id: string, notes?: string): Observable<SettlementRequestItem> {
    return this.http.post<SettlementRequestItem>(`${environment.apiUrl}/Admin/SettlementRequests/${id}/Accept`, { notes: notes || '' });
  }

  rejectRequest(id: string, reason: string): Observable<SettlementRequestItem> {
    return this.http.post<SettlementRequestItem>(`${environment.apiUrl}/Admin/SettlementRequests/${id}/Reject`, { reason });
  }

  completeMerchantRequest(id: string, notes?: string): Observable<SettlementRequestItem> {
    return this.http.post<SettlementRequestItem>(`${environment.apiUrl}/Admin/SettlementRequests/${id}/Complete`, { notes: notes || '' });
  }
}
