import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { Subscription } from 'rxjs';
import { NavigationEnd, Router } from '@angular/router';
import { ApplicationMenuGroups, findApplicationMenuLocation } from 'src/app/_metronic/config/settings';
import { environment } from '../../../../../../environments/environment';
import { NotificationSummary, NotificationSummaryService } from '../../../core/notification-summary.service';

@Component({
  selector: 'app-aside-menu',
  templateUrl: './aside-menu.component.html',
  styleUrls: ['./aside-menu.component.scss'],
})
export class AsideMenuComponent implements OnInit, OnDestroy {
  appAngularVersion: string = environment.appVersion;
  appPreviewChangelogUrl: string = environment.appVersion;
  applicationMenuGroups = ApplicationMenuGroups;
  activeWorkspaceId = 'overview';
  expandedGroupId = '';
  activeItemPath = '';
  summary: NotificationSummary | null = null;
  private sub = new Subscription();

  constructor(
    private notificationSummaryService: NotificationSummaryService,
    private cdr: ChangeDetectorRef,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.syncNavigation();
    this.sub.add(this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.syncNavigation();
    }));
    this.sub.add(
      this.notificationSummaryService.summary$.subscribe((data) => {
        this.summary = data;
        this.cdr.markForCheck();
      })
    );
  }

  private syncNavigation(): void {
    const location = findApplicationMenuLocation(this.router.url);
    if (location) {
      this.activeWorkspaceId = location.group.id;
      this.activeItemPath = location.item.path;
      this.expandedGroupId = location.group.items.length > 1 ? location.group.id : '';
    }
    this.cdr.markForCheck();
  }

  toggleGroup(id: string): void {
    this.expandedGroupId = this.expandedGroupId === id ? '' : id;
  }

  getWorkspaceBadgeCount(group: typeof ApplicationMenuGroups[number]): number {
    return group.items.reduce((total, item) => total + this.getBadgeCount(item.path), 0);
  }

  getBadgeCount(path: string): number {
    return this.notificationSummaryService.getCountForPath(this.summary, path);
  }

  getFormattedBadge(path: string): string {
    const count = this.getBadgeCount(path);
    return this.notificationSummaryService.formatCount(count);
  }

  getCollapsedBadge(path: string): string {
    const count = this.getBadgeCount(path);
    return this.notificationSummaryService.formatCollapsedCount(count);
  }

  ngOnDestroy(): void {
    this.sub.unsubscribe();
  }
}
