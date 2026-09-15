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
} from '../models/reconciliation.model';

@Injectable({
  providedIn: 'root',
})
export class ReconciliationService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/FleetReconciliation`;

  constructor(private http: HttpClient) {}

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
