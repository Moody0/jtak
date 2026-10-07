import { Injectable } from '@angular/core';
import { CanActivate, CanActivateChild, ActivatedRouteSnapshot, RouterStateSnapshot, Router } from '@angular/router';
import { catchError, map, of } from 'rxjs';
import { AuthService } from './auth.service';

@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate, CanActivateChild {
  constructor(private auth: AuthService, private router: Router) {}
  canActivate(_route: ActivatedRouteSnapshot, state: RouterStateSnapshot) {
    if (!this.auth.getToken()) return this.router.createUrlTree(['/auth/login'], { queryParams: { returnUrl: state.url } });
    return this.auth.getUserByToken().pipe(
      map(user => user?.dashboardAccess?.canAccess ? true : this.router.createUrlTree(['/auth/login'])),
      catchError(() => { this.auth.logout(); return of(this.router.createUrlTree(['/auth/login'])); })
    );
  }
  canActivateChild(_route: ActivatedRouteSnapshot, state: RouterStateSnapshot) {
    return this.auth.getUserByToken().pipe(
      map(user => !user ? this.router.createUrlTree(['/auth/login']) : this.auth.canRoute(state.url) ? true : this.router.createUrlTree(['/' + this.auth.landingRoute])),
      catchError(() => { this.auth.logout(); return of(this.router.createUrlTree(['/auth/login'])); })
    );
  }
}
