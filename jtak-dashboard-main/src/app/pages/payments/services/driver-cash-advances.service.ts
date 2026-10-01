import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from 'src/environments/environment';
import { Observable } from 'rxjs';
import { DriverCashAdvanceOverview } from '../models/driver-cash-advance.model';

@Injectable({ providedIn: 'root' })
export class DriverCashAdvancesService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/DriverCashAdvances`;

  constructor(private http: HttpClient) {}

  getOverview(): Observable<DriverCashAdvanceOverview> {
    return this.http.get<DriverCashAdvanceOverview>(`${this.baseUrl}/overview`);
  }

  create(request: {
    driverUserId: string;
    amount: number;
    reason: string;
    idempotencyKey: string;
  }): Observable<{ transactionNumber: string; amount: number; balance: number; remainingCapacity: number }> {
    return this.http.post<{ transactionNumber: string; amount: number; balance: number; remainingCapacity: number }>(
      this.baseUrl,
      request
    );
  }
}
