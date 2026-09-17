import { Injectable, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, Subscription, timer, of } from 'rxjs';
import { catchError, filter, switchMap, tap } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import { AuthService } from 'src/app/modules/auth';

export interface NotificationSummary {
  orders: number;
  supportMessages: number;
  driverSettlements: number;
  merchantSettlements: number;
  reconciliation: number;
  users: number;
  totalActionable: number;
}

@Injectable({
  providedIn: 'root',
})
export class NotificationSummaryService implements OnDestroy {
  private readonly summarySubject = new BehaviorSubject<NotificationSummary | null>(null);
  public readonly summary$: Observable<NotificationSummary | null> = this.summarySubject.asObservable();

  private pollingSub: Subscription | null = null;
  private readonly pollingIntervalMs = 25000; // 25 seconds

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {
    this.startPolling();
  }

  get currentSummary(): NotificationSummary | null {
    return this.summarySubject.value;
  }

  /**
   * Start periodic background polling for real-time notification summaries.
   * Only queries backend if user has an active session token.
   * Silently swallows transient network errors to avoid intrusive error toasts.
   */
  public startPolling(): void {
    if (this.pollingSub) {
      return;
    }

    this.pollingSub = timer(0, this.pollingIntervalMs)
      .pipe(
        filter(() => !!this.authService.getAuthFromLocalStorage()),
        switchMap(() => this.fetchSummaryObservable())
      )
      .subscribe();
  }

  /**
   * Trigger an immediate on-demand refresh (e.g. after order actions, ticket resolution, or settlement decisions)
   */
  public refresh(): void {
    if (!this.authService.getAuthFromLocalStorage()) {
      return;
    }
    this.fetchSummaryObservable().subscribe();
  }

  private fetchSummaryObservable(): Observable<NotificationSummary | null> {
    const url = `${environment.apiUrl}/Admin/Notifications/Summary`;
    return this.http.get<NotificationSummary>(url).pipe(
      tap((data) => {
        if (data) {
          this.summarySubject.next(data);
        }
      }),
      catchError((_err) => {
        // Silent failure for polling to avoid interrupting admin UI
        return of(null);
      })
    );
  }

  /**
   * Resolve pending item count for a given sidebar route path.
   */
  public getCountForPath(summary: NotificationSummary | null, path: string): number {
    if (!summary || !path) {
      return 0;
    }

    const cleanPath = path.toLowerCase().trim().replace(/^\//, '');
    switch (cleanPath) {
      case 'orders':
        return summary.orders || 0;
      case 'support-messages':
        return summary.supportMessages || 0;
      case 'reconciliation':
        return summary.reconciliation ?? ((summary.driverSettlements || 0) + (summary.merchantSettlements || 0));
      case 'users':
        return summary.users || 0;
      default:
        return 0;
    }
  }

  /**
   * Format badge display: count = 0 -> '', count > 99 -> '99+', otherwise count number as string
   */
  public formatCount(count: number): string {
    if (!count || count <= 0) {
      return '';
    }
    if (count > 99) {
      return '99+';
    }
    return count.toString();
  }

  /**
   * Format collapsed sidebar badge display: count = 0 -> '', count > 9 -> '9+', otherwise count number as string
   */
  public formatCollapsedCount(count: number): string {
    if (!count || count <= 0) {
      return '';
    }
    if (count > 9) {
      return '9+';
    }
    return count.toString();
  }

  ngOnDestroy(): void {
    if (this.pollingSub) {
      this.pollingSub.unsubscribe();
      this.pollingSub = null;
    }
  }
}
