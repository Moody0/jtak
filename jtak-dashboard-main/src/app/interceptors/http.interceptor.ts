import {
  HttpInterceptor,
  HttpHandler,
  HttpRequest,
  HttpEvent,
  HttpErrorResponse,
} from '@angular/common/http';
import { Inject, Injectable, Injector, PLATFORM_ID } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { isPlatformBrowser } from '@angular/common';
import { AuthService } from '../modules/auth';
import { GRANT_TYPES } from '../modules/auth/enums/grant-types.enum';
import { LanguageService } from 'typescript';

@Injectable()
export class AppHttpInterceptor implements HttpInterceptor {
  public authService: AuthService;
  constructor(
    public toasterService: ToastrService,
    private injector: Injector,
    @Inject(PLATFORM_ID) private platformId: any
  ) {
  }
  intercept(
    req: HttpRequest<any>,
    next: HttpHandler
  ): Observable<HttpEvent<any>> {
    if (req.url.includes('connect/token')) {
      if (req.body?.grant_type === GRANT_TYPES.REFRESH_TOKEN) {
        // if refresh_token is invalid: clear usless localstorage
        this.authService.logout()
      }
      return this.handleRequest(req, next);
    }

    if (isPlatformBrowser(this.platformId)) {
      this.authService = this.injector.get<AuthService>(AuthService);
      const authModel = this.authService.getAuthFromLocalStorage();
      if (authModel?.access_token) {
        req = req.clone({
          setHeaders: {
            Authorization: `Bearer ${authModel.access_token}`,
          },
        });
      }
    }

    req = req.clone({
      setHeaders: {
        'Accept-Language': 'ar',
      },
    });

    return this.handleRequest(req, next);
  }

  handleRequest(
    req: HttpRequest<any>,
    next: HttpHandler
  ): Observable<HttpEvent<any>> {
    return next.handle(req).pipe(
      catchError((err: any) => {
        if (isPlatformBrowser(this.platformId)) {
          if (err instanceof HttpErrorResponse) {
            if (err.status === 401) {
              // if not authorized: try geting new access_token using refresh_token (once)
              this.authService
                .login(GRANT_TYPES.REFRESH_TOKEN)
                .subscribe(user => {
                  if (user === undefined)
                    this.authService.logout();
                });
            } else {
              var msg = 'Error';
              if (err?.error?.errors)
                msg = err.error.errors.join('').replace(/\n/g, '</br>');
              this.toasterService.error(msg);
            }
          }
        }
        return of(err);
      })
    );
  }
}
