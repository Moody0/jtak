import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { RouterTestingModule } from '@angular/router/testing';
import { Routing } from '../routing';

@Component({ template: '<router-outlet></router-outlet>' })
class RoutingHost {}

@Component({ template: 'Unified settlement' })
class UnifiedSettlementPage {}

describe('Retired captain settlement route', () => {
  beforeEach(async () => {
    const legacyRoute = Routing.find(route => route.path === 'captain-settlements')!;
    await TestBed.configureTestingModule({
      declarations: [RoutingHost, UnifiedSettlementPage],
      imports: [RouterTestingModule.withRoutes([
        legacyRoute,
        { path: 'reconciliation', component: UnifiedSettlementPage },
      ])],
    }).compileComponents();
    TestBed.createComponent(RoutingHost).detectChanges();
  });

  for (const url of ['/captain-settlements', '/captain-settlements?tab=merchants&fromDate=2026-10-01']) {
    it(`redirects ${url} to the courier tab without loading the legacy module`, async () => {
      const router = TestBed.inject(Router);
      expect(await router.navigateByUrl(url)).toBeTrue();
      expect(router.url).toBe('/reconciliation?tab=couriers');
      expect(Routing.find(route => route.path === 'captain-settlements')?.loadChildren).toBeUndefined();
    });
  }
});
