import { Injectable } from '@angular/core';
//import * as moment from 'moment';
import { Observable, BehaviorSubject, of, Subscription } from 'rxjs';
import { map, finalize, tap, switchMap, catchError } from 'rxjs/operators';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { AuthModel } from '../models/auth.model';
import { environment } from 'src/environments/environment';
import { GRANT_TYPES } from '../enums/grant-types.enum';
import { UserModel } from '..';

@Injectable({
  providedIn: 'root',
})
export class AuthService {
  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/x-www-form-urlencoded',
    }),
  };

  private unsubscribe: Subscription[] = []; // Read more: => https://brianflove.com/2016/12/11/anguar-2-unsubscribe-observables/
  private authLocalStorageKey = 'sol-auth';
  private userLocalStorageKey = 'sol-user';

  // public fields
  isLoading$: Observable<boolean>;
  isLoadingSubject: BehaviorSubject<boolean>;
  user$: Observable<UserModel | undefined>;
  userSubject: BehaviorSubject<UserModel | undefined>;

  constructor(private httpClient: HttpClient) {
    this.isLoadingSubject = new BehaviorSubject<boolean>(false);
    this.isLoading$ = this.isLoadingSubject.asObservable();


    this.userSubject = new BehaviorSubject<UserModel | undefined>(undefined);
    //const subscr = this.getUserByToken().subscribe((res) => {
    //  if (res !== undefined) {
    //    this.setUserFromLocalStorage(res);
    //  }
    //});
    //this.unsubscribe.push(subscr);
    this.user$ = this.userSubject.asObservable();
    /// Restore session:
    this.restoreSession();
  }

  restoreSession() {
    // if no valid auth, delete it!
    let auth = this.getAuthFromLocalStorage();
    let expiryDate = undefined;
    if (auth?.createDate !== undefined) {
      expiryDate = new Date(auth?.createDate);
      expiryDate?.setSeconds(expiryDate?.getSeconds() + auth.expires_in);
    }
    if (expiryDate !== undefined && expiryDate < new Date()) {
      console.log('is expiered');
      // If auth is expired, try getting refresh token
      this.getAuthByToken(GRANT_TYPES.REFRESH_TOKEN)
        .pipe(
          map((auth: AuthModel) => {
            console.log('get auth by refresh token');
            auth.createDate = new Date();
            const result = this.setAuthFromLocalStorage(auth);
            return result;
          }),
          switchMap(() => this.getUserByToken()),
          map((user) => {
            if (user !== undefined)
              this.setUserFromLocalStorage(user);
            this.userSubject.next(user);
            return user;
          }),
          catchError((err) => {
            console.error('err', err);
            return of(undefined);
          }),
          finalize(() => this.isLoadingSubject.next(false))
        );
    }
    var user = this.getUserFromLocalStorage();
    if (user !== undefined) {
      this.userSubject.next(user);
    }
  }
  // public methods
  login(
    type: GRANT_TYPES,
    email?: string,
    password?: string
  ): Observable<UserModel | undefined> {
    this.isLoadingSubject.next(true);
    return this.getAuthByToken(type, email as string, password as string)
      .pipe(
        map((auth: AuthModel) => {
          auth.createDate = new Date();
          const result = this.setAuthFromLocalStorage(auth);
          return result;
        }),
        switchMap(() => this.getUserByToken()),
        map((user) => {
          if (user !== undefined)
            this.setUserFromLocalStorage(user);
          return user;
        }),
        catchError((err) => {
          console.error('err', err);
          return of(undefined);
        }),
        finalize(() => this.isLoadingSubject.next(false))
      );
  }

  getAuthByToken(
    type: GRANT_TYPES,
    username?: string,
    password?: string): Observable<AuthModel> {
    let params = new HttpParams();
    if (type === GRANT_TYPES.PASSWORD) {
      params = params.set('username', username as string)
        .set('password', password as string)
        .set('grant_type', type)
        .set('scope', 'offline_access profile roles phone email');
    } else if (type === GRANT_TYPES.REFRESH_TOKEN) {
      const authData = this.getAuthFromLocalStorage();
      if (authData)
        params = params.set('refresh_token', authData.refresh_token)
          .set('grant_type', type)
          .set('scope', 'offline_access');
    }

    return this.httpClient
      .post<AuthModel>(
        environment.baseUrl + '/connect/token',
        params.toString(),
        this.httpOptions
      )
  }

  forgotPassword(values: any): Observable<boolean> {
    this.isLoadingSubject.next(true);
    return this.httpClient
      .post<boolean>(environment.apiUrl + '/ForgetPasswordConfirm', values)
      .pipe(finalize(() => this.isLoadingSubject.next(false)));
  }

  logout() {
    localStorage.removeItem(this.authLocalStorageKey);
    localStorage.removeItem(this.userLocalStorageKey);
    document.location.replace('/auth/login');
  }

  fetchUserData(): Observable<any> {
    this.isLoadingSubject.next(true);
    return this.httpClient.get(environment.apiUrl + '/Authorization/Account').pipe(
      tap((res: any) => {
        this.userSubject.next(res.user);
        localStorage.setItem(this.userLocalStorageKey, JSON.stringify(res.user));
      }),
      finalize(() => {
        this.isLoadingSubject.next(false);
      })
    );
  }

  //getClaims() {
  //  const user = JSON.parse(localStorage.getItem(this.authLocalStorageKey));
  //  return user && user.claims;
  //}

  //showBasedOnClaim(claim) {
  //  const claims = this.getClaims();
  //  return claims && claims.length > 0 && claims.includes(claim);
  //}

  getToken(): string | undefined {
    return this.getAuthFromLocalStorage()?.access_token;
  }

  getUserByToken(): Observable<UserModel | undefined> {
    const auth = this.getAuthFromLocalStorage();
    if (!auth || !auth.access_token) {
      return of(undefined);
    }

    this.isLoadingSubject.next(true);
    return this.fetchUserData().pipe(
      map((user: UserModel) => {
        if (user) {
          this.userSubject.next(user);
        } else {
          this.logout();
        }
        return user;
      }),
      finalize(() => this.isLoadingSubject.next(false))
    );
  }

  public getAuthFromLocalStorage(): AuthModel | undefined {
    try {
      const lsValue = localStorage.getItem(this.authLocalStorageKey);
      if (!lsValue) {
        return undefined;
      }

      const authData = JSON.parse(lsValue);
      return authData;
    } catch (error) {
      console.error(error);
      return undefined;
    }
  }

  private setAuthFromLocalStorage(auth: AuthModel): boolean {
    // store auth authToken/refreshToken/epiresIn in local storage to keep user logged in between page refreshes
    if (auth && auth.access_token) {
      localStorage.setItem(this.authLocalStorageKey, JSON.stringify(auth));
      return true;
    }
    return false;
  }

  private getUserFromLocalStorage(): UserModel | undefined {
    try {
      const lsValue = localStorage.getItem(this.userLocalStorageKey);
      if (!lsValue) {
        return undefined;
      }

      const authData = JSON.parse(lsValue);
      return authData;
    } catch (error) {
      console.error(error);
      return undefined;
    }
  }

  private setUserFromLocalStorage(user: UserModel): boolean {
    // store auth authToken/refreshToken/epiresIn in local storage to keep user logged in between page refreshes
    if (user && user.id) {
      localStorage.setItem(this.userLocalStorageKey, JSON.stringify(user));
      return true;
    }
    return false;
  }


  ngOnDestroy() {
    this.unsubscribe.forEach((sb) => sb.unsubscribe());
  }
}
