import { Injectable } from '@angular/core';
import { Observable, BehaviorSubject, of, Subscription } from 'rxjs';
import { map, finalize, tap, switchMap, catchError } from 'rxjs/operators';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { AuthModel } from '../models/auth.model';
import { environment } from 'src/environments/environment';
import { GRANT_TYPES } from '../enums/grant-types.enum';
import { UserModel } from '..';

import { Router } from '@angular/router';

@Injectable({
  providedIn: 'root',
})
export class AuthService {
  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/x-www-form-urlencoded',
    }),
  };

  private unsubscribe: Subscription[] = [];
  private readonly authSessionStorageKey = 'sol-session-auth';
  private readonly userSessionStorageKey = 'sol-session-user';

  // public fields
  isLoading$: Observable<boolean>;
  isLoadingSubject: BehaviorSubject<boolean>;
  user$: Observable<UserModel | undefined>;
  userSubject: BehaviorSubject<UserModel | undefined>;

  constructor(
    private httpClient: HttpClient,
    private router: Router
  ) {
    this.cleanupLegacyPersistentAuth();
    this.isLoadingSubject = new BehaviorSubject<boolean>(false);
    this.isLoading$ = this.isLoadingSubject.asObservable();
    this.userSubject = new BehaviorSubject<UserModel | undefined>(undefined);
    this.user$ = this.userSubject.asObservable();
    this.restoreSession();
  }

  /**
   * Safely removes legacy persistent localStorage Admin auth keys so old remembered logins
   * cannot authenticate future sessions across browser closures.
   * Does NOT touch unrelated preferences (e.g. language, theme, layout).
   */
  private cleanupLegacyPersistentAuth(): void {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        const legacyAuthKeys = [
          'sol-auth',
          'sol-user',
          'remember-me',
          'auth_remember',
          'rememberMe',
          'sol-remember',
          'admin-auth',
          'admin-user',
        ];
        for (const key of legacyAuthKeys) {
          window.localStorage.removeItem(key);
        }
      }
    } catch (e) {
      console.warn('Unable to clean legacy localStorage auth keys', e);
    }
  }

  restoreSession() {
    const auth = this.getAuthFromSessionStorage();
    if (!auth || !auth.access_token) {
      return;
    }

    let expiryDate = undefined;
    if (auth?.createDate !== undefined) {
      expiryDate = new Date(auth.createDate);
      expiryDate.setSeconds(expiryDate.getSeconds() + (auth.expires_in || 0));
    }

    if (expiryDate !== undefined && expiryDate < new Date()) {
      // If session auth token expired within the active session, try refreshing it
      this.getAuthByToken(GRANT_TYPES.REFRESH_TOKEN)
        .pipe(
          map((refreshedAuth: AuthModel) => {
            refreshedAuth.createDate = new Date();
            this.setAuthToSessionStorage(refreshedAuth);
            return refreshedAuth;
          }),
          switchMap(() => this.getUserByToken()),
          map((user) => {
            if (user !== undefined) {
              this.setUserToSessionStorage(user);
            }
            this.userSubject.next(user);
            return user;
          }),
          catchError((err) => {
            console.error('Session refresh error', err);
            this.logout();
            return of(undefined);
          }),
          finalize(() => this.isLoadingSubject.next(false))
        )
        .subscribe();
      return;
    }

    const user = this.getUserFromSessionStorage();
    if (user !== undefined) {
      this.userSubject.next(user);
    }
  }

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
          const result = this.setAuthToSessionStorage(auth);
          return result;
        }),
        switchMap(() => this.getUserByToken()),
        map((user) => {
          if (user !== undefined) {
            this.setUserToSessionStorage(user);
          }
          return user;
        }),
        catchError((err) => {
          console.error('Login error', err);
          return of(undefined);
        }),
        finalize(() => this.isLoadingSubject.next(false))
      );
  }

  getAuthByToken(
    type: GRANT_TYPES,
    username?: string,
    password?: string
  ): Observable<AuthModel> {
    let params = new HttpParams();
    if (type === GRANT_TYPES.PASSWORD) {
      params = params
        .set('username', username as string)
        .set('password', password as string)
        .set('grant_type', type)
        .set('scope', 'offline_access profile roles phone email');
    } else if (type === GRANT_TYPES.REFRESH_TOKEN) {
      const authData = this.getAuthFromSessionStorage();
      if (authData) {
        params = params
          .set('refresh_token', authData.refresh_token)
          .set('grant_type', type)
          .set('scope', 'offline_access');
      }
    }

    return this.httpClient.post<AuthModel>(
      environment.baseUrl + '/connect/token',
      params.toString(),
      this.httpOptions
    );
  }

  forgotPassword(values: any): Observable<boolean> {
    this.isLoadingSubject.next(true);
    return this.httpClient
      .post<boolean>(environment.apiUrl + '/ForgetPasswordConfirm', values)
      .pipe(finalize(() => this.isLoadingSubject.next(false)));
  }

  logout() {
    this.cleanupLegacyPersistentAuth();
    try {
      if (typeof window !== 'undefined' && window.sessionStorage) {
        sessionStorage.removeItem(this.authSessionStorageKey);
        sessionStorage.removeItem(this.userSessionStorageKey);
      }
    } catch (e) {
      console.warn('Error clearing sessionStorage', e);
    }
    this.userSubject.next(undefined);
    this.router.navigate(['/auth/login']);
  }

  fetchUserData(): Observable<any> {
    this.isLoadingSubject.next(true);
    return this.httpClient.get(environment.apiUrl + '/Authorization/Account').pipe(
      tap((res: any) => {
        this.userSubject.next(res.user);
        this.setUserToSessionStorage(res.user);
      }),
      finalize(() => {
        this.isLoadingSubject.next(false);
      })
    );
  }

  getToken(): string | undefined {
    return this.getAuthFromSessionStorage()?.access_token;
  }

  getUserByToken(): Observable<UserModel | undefined> {
    const auth = this.getAuthFromSessionStorage();
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

  public getAuthFromSessionStorage(): AuthModel | undefined {
    try {
      if (typeof window === 'undefined' || !window.sessionStorage) {
        return undefined;
      }
      const ssValue = sessionStorage.getItem(this.authSessionStorageKey);
      if (!ssValue) {
        return undefined;
      }
      const authData = JSON.parse(ssValue);
      return authData;
    } catch (error) {
      console.error(error);
      return undefined;
    }
  }

  /**
   * Compatibility alias pointing strictly to session-based storage.
   */
  public getAuthFromLocalStorage(): AuthModel | undefined {
    return this.getAuthFromSessionStorage();
  }

  private setAuthToSessionStorage(auth: AuthModel): boolean {
    if (auth && auth.access_token) {
      try {
        if (typeof window !== 'undefined' && window.sessionStorage) {
          sessionStorage.setItem(this.authSessionStorageKey, JSON.stringify(auth));
          return true;
        }
      } catch (e) {
        console.error('Failed to write auth to sessionStorage', e);
      }
    }
    return false;
  }

  public getUserFromSessionStorage(): UserModel | undefined {
    try {
      if (typeof window === 'undefined' || !window.sessionStorage) {
        return undefined;
      }
      const ssValue = sessionStorage.getItem(this.userSessionStorageKey);
      if (!ssValue) {
        return undefined;
      }
      const userData = JSON.parse(ssValue);
      return userData;
    } catch (error) {
      console.error(error);
      return undefined;
    }
  }

  /**
   * Compatibility alias pointing strictly to session-based user storage.
   */
  public getUserFromLocalStorage(): UserModel | undefined {
    return this.getUserFromSessionStorage();
  }

  private setUserToSessionStorage(user: UserModel): boolean {
    if (user && user.id) {
      try {
        if (typeof window !== 'undefined' && window.sessionStorage) {
          sessionStorage.setItem(this.userSessionStorageKey, JSON.stringify(user));
          return true;
        }
      } catch (e) {
        console.error('Failed to write user to sessionStorage', e);
      }
    }
    return false;
  }

  ngOnDestroy() {
    this.unsubscribe.forEach((sb) => sb.unsubscribe());
  }
}
