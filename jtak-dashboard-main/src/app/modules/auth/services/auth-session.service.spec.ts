import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { Router } from '@angular/router';
import { RouterTestingModule } from '@angular/router/testing';
import { AuthService } from './auth.service';
import { AuthGuard } from './auth.guard';
import { AuthModel } from '../models/auth.model';
import { UserModel } from '../models/user.model';

describe('Admin Session-Only Authentication & Route Guard', () => {
  let authService: AuthService;
  let authGuard: AuthGuard;
  let router: Router;

  beforeEach(() => {
    // Populate legacy persistent keys to verify automatic migration/cleanup
    localStorage.setItem('sol-auth', JSON.stringify({ access_token: 'legacy-token' }));
    localStorage.setItem('sol-user', JSON.stringify({ id: 'legacy-user' }));
    localStorage.setItem('remember-me', 'true');
    localStorage.setItem('language', 'ar'); // Unrelated preference — must remain untouched

    sessionStorage.clear();

    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule, RouterTestingModule],
      providers: [AuthService, AuthGuard],
    });

    authService = TestBed.inject(AuthService);
    authGuard = TestBed.inject(AuthGuard);
    router = TestBed.inject(Router);
    spyOn(router, 'navigate').and.stub();
  });

  afterEach(() => {
    sessionStorage.clear();
    localStorage.removeItem('sol-auth');
    localStorage.removeItem('sol-user');
    localStorage.removeItem('remember-me');
  });

  it('1. Automatically cleans up legacy persistent auth keys without deleting language preference', () => {
    expect(localStorage.getItem('sol-auth')).toBeNull();
    expect(localStorage.getItem('sol-user')).toBeNull();
    expect(localStorage.getItem('remember-me')).toBeNull();
    expect(localStorage.getItem('language')).toBe('ar');
  });

  it('2. Does NOT authenticate Admin from legacy localStorage on clean browser session', () => {
    expect(authService.getAuthFromSessionStorage()).toBeUndefined();
    expect(authService.getToken()).toBeUndefined();
    expect(authService.userSubject.value).toBeUndefined();
  });

  it('3. AuthGuard blocks unauthenticated access and redirects to /auth/login with returnUrl', () => {
    const routeMock: any = {};
    const stateMock: any = { url: '/orders' };

    const result = authGuard.canActivate(routeMock, stateMock);

    expect(result).toBeFalse();
    expect(router.navigate).toHaveBeenCalledWith(['auth/login'], {
      queryParams: { returnUrl: '/orders' },
    });
  });

  it('4. Stores auth data in sessionStorage only and preserves session on same-tab navigation', () => {
    const mockAuth: AuthModel = {
      access_token: 'test-session-access-token',
      token_type: 'Bearer',
      refresh_token: 'test-session-refresh-token',
      expires_in: 3600,
      createDate: new Date(),
    };
    const mockUser: Partial<UserModel> = {
      id: 'admin-uuid-1',
      email: 'admin@jtak.app',
      fullName: 'Admin User',
      isActive: true,
    };

    sessionStorage.setItem('sol-session-auth', JSON.stringify(mockAuth));
    sessionStorage.setItem('sol-session-user', JSON.stringify(mockUser));

    expect(authService.getAuthFromSessionStorage()?.access_token).toBe('test-session-access-token');
    expect(authService.getUserFromSessionStorage()?.id).toBe('admin-uuid-1');

    // Never written to localStorage
    expect(localStorage.getItem('sol-session-auth')).toBeNull();
    expect(localStorage.getItem('sol-auth')).toBeNull();

    // Guard allows active session
    const routeMock: any = {};
    const stateMock: any = { url: '/dashboard' };
    const guardResult = authGuard.canActivate(routeMock, stateMock);
    expect(guardResult).toBeTrue();
  });

  it('5. Explicit logout clears sessionStorage and triggers redirection', () => {
    sessionStorage.setItem('sol-session-auth', JSON.stringify({ access_token: 'active-token' }));
    sessionStorage.setItem('sol-session-user', JSON.stringify({ id: 'user-1' }));

    authService.logout();

    expect(sessionStorage.getItem('sol-session-auth')).toBeNull();
    expect(sessionStorage.getItem('sol-session-user')).toBeNull();
    expect(authService.userSubject.value).toBeUndefined();
    expect(router.navigate).toHaveBeenCalledWith(['/auth/login']);
  });
});
