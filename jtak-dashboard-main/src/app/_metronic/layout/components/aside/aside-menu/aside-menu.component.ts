import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { Subscription } from 'rxjs';
import { ApplicationMenuGroups } from 'src/app/_metronic/config/settings';
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
  summary: NotificationSummary | null = null;
  private sub = new Subscription();

  constructor(
    private notificationSummaryService: NotificationSummaryService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.sub.add(
      this.notificationSummaryService.summary$.subscribe((data) => {
        this.summary = data;
        this.cdr.markForCheck();
      })
    );
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
