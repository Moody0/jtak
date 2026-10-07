import { AuthService } from 'src/app/modules/auth';
import { dashboardSection } from 'src/app/modules/auth/models/dashboard-access.model';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { ApplicationMenuGroups, findApplicationMenuLocation } from '../../../config/settings';

@Component({
  selector: 'app-workspace-nav',
  templateUrl: './workspace-nav.component.html',
  styleUrls: ['./workspace-nav.component.scss'],
})
export class WorkspaceNavComponent implements OnInit, OnDestroy {
  group: typeof ApplicationMenuGroups[number] | null = null;
  activePath = '';
  private subscription = new Subscription();

  constructor(private router: Router, public auth: AuthService) {}

  ngOnInit(): void {
    this.subscription.add(this.auth.user$.subscribe(() => this.updateFromRoute()));
    this.updateFromRoute();
    this.subscription.add(this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.updateFromRoute();
    }));
  }

  private updateFromRoute(): void {
    const location = findApplicationMenuLocation(this.router.url);
    const group = location ? { ...location.group, items: location.group.items.filter(item => this.auth.canRoute(item.path)) } : null;
    this.group = group && group.items.length > 1 ? group : null;
    this.activePath = location?.item.path || '';
  }

  get readOnly(): boolean {
    const section = dashboardSection(this.router.url);
    return !!section && this.auth.can(section + '.view') && !this.auth.can(section + '.manage');
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
  }
}
