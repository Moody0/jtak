import { Injectable } from '@angular/core';
import {
  CanActivate,
  ActivatedRouteSnapshot,
  RouterStateSnapshot,
  Router,
} from '@angular/router';
import { Observable, map, of } from 'rxjs';
import { AuthService } from './auth.service';

@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(private authService: AuthService, private router: Router) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean> | boolean {
    const auth = this.authService.getAuthFromSessionStorage();
    if (!auth || !auth.access_token) {
      this.router.navigate(['auth/login'], {
        queryParams: { returnUrl: state.url },
      });
      return false;
    }

    const currentUser =
      this.authService.userSubject.value ||
      this.authService.getUserFromSessionStorage();
    if (currentUser) {
      if (!this.authService.userSubject.value) {
        this.authService.userSubject.next(currentUser);
      }
      return true;
    }

    return this.authService.user$.pipe(
      map((user) => {
        if (!user) {
          this.router.navigate(['auth/login'], {
            queryParams: { returnUrl: state.url },
          });
          return false;
        }
        return true;
      })
    );
  }
}
