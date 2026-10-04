import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Balance, User } from '../models/user.model';
import { environment } from 'src/environments/environment';
import { TableService, TableResponseModel } from 'src/app/_metronic/shared/crud-table';
import { finalize, Observable, tap, BehaviorSubject } from 'rxjs';
import { map } from 'rxjs/operators';
import { TagVal } from '../models/TagVal-dto.model';

@Injectable({
  providedIn: 'root',
})
export class UsersService extends TableService<User> implements OnDestroy {
  readonly summary$=new BehaviorSubject<any>(null);
  protected onListResponse(response:any):void {this.summary$.next(response?.summary ?? null);}
  BASE_URL = environment.apiUrl;
  GET_ALL_URL = 'Admin/Users/DataTable';
  GET_ONE_URL = 'Admin/Users';
  CREATE_URL = 'Admin/Users';
  UPDATE_URL = 'Admin/Users';
  DELETE_URL = 'Admin/Users';

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  constructor(@Inject(HttpClient) public http: HttpClient) {
    super(http);
  }

  getAllUsers(): Observable<User[]> {
    return this.http
      .post<TableResponseModel<User>>(
        `${this.BASE_URL}/${this.GET_ALL_URL}`,
        // The API uses one-based page numbers (the UI paginator is zero-based).
        { pageNumber: 1, pageSize: 500, filter: {} },
        this.httpOptions
      )
      .pipe(map((res) => res.items || []));
  }

  getMerchantUsers(): Observable<User[]> {
    return this.http
      .get<User[]>(`${this.BASE_URL}/Admin/Users/Merchants`)
      .pipe(map((users) => users || []));
  }

  resetMerchantPassword(userId: string, newPassword: string): Observable<void> {
    return this.http.post<void>(
      `${this.BASE_URL}/Admin/Users/${userId}/ResetPassword`,
      { newPassword },
      this.httpOptions
    );
  }

  changeUserStatus(isActive: boolean, userId: string) {
    this._isLoading$.next(true);
    return this.http
      .put(
        `${this.BASE_URL}/Admin/Users/${userId}/${
          isActive ? 'Disable' : 'Enable'
        }`,
        {}
      )
      .pipe(
        finalize(() => {
          this._isLoading$.next(false);
        })
      );
  }

  getBalance(id: string) {
    return this.http.get<Balance>(`${this.BASE_URL}/Admin/Balances/${id}`);
  }

  getRoles(): Observable<TagVal[]> {
    return this.http.get<TagVal[]>(`${this.BASE_URL}/Admin/Users/Roles`);
  }

  getDeliveries(): Observable<User[]> {
    return this.http.get<User[]>(`${this.BASE_URL}/Admin/Users/Deliveries`);
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }
}
