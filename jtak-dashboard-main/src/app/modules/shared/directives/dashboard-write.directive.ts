import { Directive, ElementRef, HostBinding, Input } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../auth/services/auth.service';
import { dashboardSection } from '../../auth/models/dashboard-access.model';

/** UI convenience only; the API enforces every operation independently. */
@Directive({ selector: '[appDashboardWrite]', standalone: true })
export class DashboardWriteDirective {
  @Input() appDashboardWrite = '';
  private originalDisplay: string;
  constructor(private auth: AuthService, private router: Router, element: ElementRef<HTMLElement>) {
    this.originalDisplay = element.nativeElement.style.display;
  }
  @HostBinding('style.display') get display(): string | null {
    const section = this.appDashboardWrite || dashboardSection(this.router.url);
    return section && !this.auth.can(section + '.manage') ? 'none' : this.originalDisplay || null;
  }
}
