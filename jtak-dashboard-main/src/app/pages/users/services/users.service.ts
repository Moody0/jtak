import { Injectable, Inject, OnDestroy } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Balance, User } from '../models/user.model';
import { environment } from 'src/environments/environment';
import { TableService } from 'src/app/_metronic/shared/crud-table';
import { finalize, Observable, tap } from 'rxjs';
import { TagVal } from '../models/TagVal-dto.model';

@Injectable({
  providedIn: 'root',
})
export class UsersService extends TableService<User> implements OnDestroy {
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

  getMerchantUsers() : Observable<User[]>{    
    return this.http.get<User[]>(`${this.BASE_URL}/Admin/Users/Merchants`);
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

  getBalance(id:string) {
    return this.http.get<Balance>(`${this.BASE_URL}/Admin/Balances/${id}`)
  }

  getRoles():Observable<TagVal[]>
  {
    return this.http.get<TagVal[]>(`${this.BASE_URL}/Admin/Users/Roles`)
  }
  getDeliveries():Observable<User[]>
  {
    return this.http.get<User[]>(`${this.BASE_URL}/Admin/Users/Deliveries`)
  }

  ngOnDestroy() {
    this.subscriptions.forEach((sb) => sb.unsubscribe());
  }

}
