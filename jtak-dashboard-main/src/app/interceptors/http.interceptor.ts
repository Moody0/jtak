import {
  HttpInterceptor,
  HttpHandler,
  HttpRequest,
  HttpEvent,
  HttpErrorResponse,
} from '@angular/common/http';
import { Inject, Injectable, Injector, PLATFORM_ID } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { isPlatformBrowser } from '@angular/common';
import { AuthService } from '../modules/auth';
import { GRANT_TYPES } from '../modules/auth/enums/grant-types.enum';

@Injectable()
export class AppHttpInterceptor implements HttpInterceptor {
  private authService: AuthService | null = null;

  constructor(
    public toasterService: ToastrService,
    private injector: Injector,
    @Inject(PLATFORM_ID) private platformId: any
  ) {}

  private getAuthService(): AuthService | null {
    if (!this.authService && isPlatformBrowser(this.platformId)) {
      try {
        this.authService = this.injector.get<AuthService>(AuthService);
      } catch {
        // injector not ready yet
      }
    }
    return this.authService;
  }

  intercept(
    req: HttpRequest<any>,
    next: HttpHandler
  ): Observable<HttpEvent<any>> {
    const lang = (isPlatformBrowser(this.platformId) ? localStorage.getItem('language') : null) || 'ar';
    const setHeaders: { [key: string]: string } = {
      'Accept-Language': lang,
    };

    if (isPlatformBrowser(this.platformId)) {
      const auth = this.getAuthService();
      const authModel = auth?.getAuthFromSessionStorage() || auth?.getAuthFromLocalStorage();
      if (authModel?.access_token) {
        setHeaders['Authorization'] = `Bearer ${authModel.access_token}`;
      }
    }

    req = req.clone({ setHeaders });

    if (req.url.includes('connect/token')) {
      return this.handleRequest(req, next);
    }

    return this.handleRequest(req, next);
  }

  handleRequest(
    req: HttpRequest<any>,
    next: HttpHandler
  ): Observable<HttpEvent<any>> {
    return next.handle(req).pipe(
      catchError((err: any) => {
        if (isPlatformBrowser(this.platformId) && err instanceof HttpErrorResponse) {
          const auth = this.getAuthService();
          if (err.status === 401) {
            if (req.url.includes('connect/token')) {
              // Refresh token endpoint itself failed - session is no longer valid
              auth?.logout();
            } else {
              // Try getting a new access_token using refresh_token
              auth?.login(GRANT_TYPES.REFRESH_TOKEN).subscribe(user => {
                if (user === undefined) {
                  auth?.logout();
                }
              });
            }
          } else if (!req.headers.has('X-Silent-Error') && !req.url.includes('/Batches/Kpis')) {
            let msg = '';
            const isTechnicalError = (text: string) =>
              /context instance|entity framework|sql|exception|nullreference|invalidoperation|stacktrace|inner exception|table '|column '|linq/i.test(text);

            if (err.status >= 500) {
              msg = 'حدث خطأ في الخادم أثناء معالجة الطلب. يرجى المحاولة لاحقاً.';
            } else if (typeof err?.error === 'string' && err.error.trim().length > 0 && !isTechnicalError(err.error)) {
              msg = err.error.trim();
            } else if (err?.error?.errors) {
              if (Array.isArray(err.error.errors)) {
                const safeErrors = err.error.errors.filter((e: any) => typeof e === 'string' && !isTechnicalError(e));
                if (safeErrors.length > 0) {
                  msg = safeErrors.join('<br/>').replace(/\n/g, '<br/>');
                }
              } else if (typeof err.error.errors === 'object') {
                const errorLists: any[] = Object.keys(err.error.errors)
                  .map(k => (err.error.errors as any)[k]);
                const flattened = ([] as any[]).concat(...errorLists)
                  .filter((e: any) => typeof e === 'string' && !isTechnicalError(e));
                if (flattened.length > 0) {
                  msg = flattened.join('<br/>');
                }
              }
            } else if (err?.error?.message && !isTechnicalError(err.error.message)) {
              msg = err.error.message;
            } else if (err?.error?.title && !isTechnicalError(err.error.title)) {
              msg = err.error.title;
            }

            if (!msg) {
              if (err.status === 404) {
                msg = 'العنصر المطلوب غير موجود.';
              } else if (err.status === 403) {
                msg = 'ليس لديك الصلاحية لتنفيذ هذا الإجراء.';
              } else if (err.status === 400) {
                msg = 'بيانات الطلب غير صالحة. يرجى التحقق وإعادة المحاولة.';
              } else {
                msg = 'حدث خطأ أثناء معالجة الطلب. يرجى المحاولة لاحقاً.';
              }
            }

            if (msg) {
              this.toasterService.error(msg);
            }
          }
        }
        return throwError(() => err);
      })
    );
  }
}
