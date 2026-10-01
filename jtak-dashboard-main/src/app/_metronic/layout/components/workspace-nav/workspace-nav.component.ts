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

  constructor(private router: Router) {}

  ngOnInit(): void {
    this.updateFromRoute();
    this.subscription.add(this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.updateFromRoute();
    }));
  }

  private updateFromRoute(): void {
    const location = findApplicationMenuLocation(this.router.url);
    this.group = location && location.group.items.length > 1 ? location.group : null;
    this.activePath = location?.item.path || '';
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
  }
}
