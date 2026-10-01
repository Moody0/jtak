import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import {
  CaptainSettlementsOverview,
  CaptainOrdersSettlementDetail,
  ConfirmCaptainSettlementRequest,
  SettlementBatchReceipt,
  CaptainLookupItem,
} from '../models/captain-settlement.model';

@Injectable({
  providedIn: 'root',
})
export class CaptainSettlementService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/CaptainSettlements`;

  constructor(private http: HttpClient) {}

  getCaptains(): Observable<CaptainLookupItem[]> {
    return this.http.get<CaptainLookupItem[]>(`${this.baseUrl}/Captains`);
  }

  getSummary(params: {
    fromDate?: string;
    toDate?: string;
    captainId?: string;
    settlementStatus?: string;
    searchTerm?: string;
  }): Observable<CaptainSettlementsOverview> {
    const queryParts: string[] = [];

    if (params.fromDate) queryParts.push(`fromDate=${encodeURIComponent(params.fromDate)}`);
    if (params.toDate) queryParts.push(`toDate=${encodeURIComponent(params.toDate)}`);
    if (params.captainId) queryParts.push(`captainId=${encodeURIComponent(params.captainId)}`);
    if (params.settlementStatus) queryParts.push(`settlementStatus=${encodeURIComponent(params.settlementStatus)}`);
    if (params.searchTerm) queryParts.push(`searchTerm=${encodeURIComponent(params.searchTerm.trim())}`);

    const queryString = queryParts.length > 0 ? `?${queryParts.join('&')}` : '';
    return this.http.get<CaptainSettlementsOverview>(`${this.baseUrl}/Summary${queryString}`);
  }

  getCaptainOrders(
    captainId: string,
    params: {
      fromDate?: string;
      toDate?: string;
      settlementStatus?: string;
    }
  ): Observable<CaptainOrdersSettlementDetail> {
    const queryParts: string[] = [];

    if (params.fromDate) queryParts.push(`fromDate=${encodeURIComponent(params.fromDate)}`);
    if (params.toDate) queryParts.push(`toDate=${encodeURIComponent(params.toDate)}`);
    if (params.settlementStatus) queryParts.push(`settlementStatus=${encodeURIComponent(params.settlementStatus)}`);

    const queryString = queryParts.length > 0 ? `?${queryParts.join('&')}` : '';
    return this.http.get<CaptainOrdersSettlementDetail>(`${this.baseUrl}/Captain/${captainId}/Orders${queryString}`);
  }

  confirmSettlement(request: ConfirmCaptainSettlementRequest): Observable<SettlementBatchReceipt> {
    return this.http.post<SettlementBatchReceipt>(`${this.baseUrl}/ConfirmSettlement`, request);
  }

  getBatchReceipt(batchCode: string): Observable<SettlementBatchReceipt> {
    return this.http.get<SettlementBatchReceipt>(`${this.baseUrl}/Batches/${encodeURIComponent(batchCode)}`);
  }
}
