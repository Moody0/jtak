import {
  AfterViewInit,
  Component,
  ElementRef,
  OnDestroy,
  OnInit,
  ViewChild,
} from '@angular/core';
import { NavigationCancel, NavigationEnd, NavigationStart, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { LayoutService } from '../../core/layout.service';
import { environment } from './../../../../../environments/environment';
import {
  MenuComponent,
  DrawerComponent,
  ToggleComponent,
  ScrollComponent,
} from '../../../kt/components';

@Component({
  selector: 'app-aside',
  templateUrl: './aside.component.html',
  styleUrls: ['./aside.component.scss'],
})
export class AsideComponent implements OnInit, AfterViewInit, OnDestroy {
  asideTheme: string = '';
  asideMinimize: boolean = false;
  asideMenuCSSClasses: string = '';
  isMinimized: boolean = false;
  copyRightUrl: string = environment.copyRightUrl;
  @ViewChild('ktAsideScroll', { static: true }) ktAsideScroll: ElementRef;
  private unsubscribe: Subscription[] = [];
  private lastScrollTop: number = 0;

  constructor(private layout: LayoutService, private router: Router) {}

  ngOnInit(): void {
    this.asideTheme = this.layout.getProp('aside.theme') as string;
    this.asideMinimize = this.layout.getProp('aside.minimize') as boolean;
    this.asideMenuCSSClasses = this.layout.getStringCSSClasses('asideMenu');

    // Check stored or initial minimize state
    const saved = localStorage.getItem('jtak_aside_minimize');
    if (saved === 'on') {
      document.body.setAttribute('data-kt-aside-minimize', 'on');
      document.documentElement.setAttribute('data-kt-aside-minimize', 'on');
      this.isMinimized = true;
    } else if (saved === 'off') {
      document.body.removeAttribute('data-kt-aside-minimize');
      document.documentElement.removeAttribute('data-kt-aside-minimize');
      this.isMinimized = false;
    } else {
      this.isMinimized = document.body.getAttribute('data-kt-aside-minimize') === 'on';
      if (this.isMinimized) {
        document.documentElement.setAttribute('data-kt-aside-minimize', 'on');
      }
    }

    try {
      const savedScroll = sessionStorage.getItem('jtak_aside_scroll');
      if (savedScroll) {
        this.lastScrollTop = parseInt(savedScroll, 10) || 0;
      }
    } catch (e) {}

    this.routingChanges();
  }

  ngAfterViewInit(): void {
    if (this.ktAsideScroll && this.ktAsideScroll.nativeElement && this.lastScrollTop > 0) {
      this.ktAsideScroll.nativeElement.scrollTop = this.lastScrollTop;
    }
  }

  onAsideScroll(event: Event): void {
    const target = event.target as HTMLElement;
    if (target) {
      this.lastScrollTop = target.scrollTop;
      try {
        sessionStorage.setItem('jtak_aside_scroll', target.scrollTop.toString());
      } catch (e) {}
    }
  }

  toggleAsideMinimize(): void {
    this.isMinimized = !this.isMinimized;
    const body = document.body;
    const doc = document.documentElement;

    if (this.isMinimized) {
      body.setAttribute('data-kt-aside-minimize', 'on');
      doc.setAttribute('data-kt-aside-minimize', 'on');
      try { localStorage.setItem('jtak_aside_minimize', 'on'); } catch (e) {}
    } else {
      body.removeAttribute('data-kt-aside-minimize');
      doc.removeAttribute('data-kt-aside-minimize');
      try { localStorage.setItem('jtak_aside_minimize', 'off'); } catch (e) {}
    }

    // Allow the 300ms CSS transition to run completely uninterrupted at 60fps
    // Update scroll dimensions only after transition finishes
    setTimeout(() => {
      try {
        if (this.ktAsideScroll && this.ktAsideScroll.nativeElement) {
          const instance = ScrollComponent.getInstance(this.ktAsideScroll.nativeElement);
          if (instance) {
            instance.update();
          }
        }
      } catch (e) {}
    }, 350);
  }

  routingChanges() {
    const routerSubscription = this.router.events.subscribe((event) => {
      if (event instanceof NavigationStart) {
        if (this.ktAsideScroll && this.ktAsideScroll.nativeElement) {
          this.lastScrollTop = this.ktAsideScroll.nativeElement.scrollTop;
          try {
            sessionStorage.setItem('jtak_aside_scroll', this.lastScrollTop.toString());
          } catch (e) {}
        }
      }
      if (event instanceof NavigationEnd || event instanceof NavigationCancel) {
        this.menuReinitialization();
      }
    });
    this.unsubscribe.push(routerSubscription);
  }

  menuReinitialization() {
    const targetScrollTop = this.ktAsideScroll?.nativeElement
      ? (this.ktAsideScroll.nativeElement.scrollTop || this.lastScrollTop)
      : this.lastScrollTop;

    setTimeout(() => {
      MenuComponent.reinitialization();
      DrawerComponent.reinitialization();
      ToggleComponent.reinitialization();
      ScrollComponent.reinitialization();

      if (this.ktAsideScroll && this.ktAsideScroll.nativeElement) {
        // Maintain vertical scroll position exactly where the user scrolled it
        if (targetScrollTop > 0) {
          this.ktAsideScroll.nativeElement.scrollTop = targetScrollTop;
          requestAnimationFrame(() => {
            if (this.ktAsideScroll?.nativeElement) {
              this.ktAsideScroll.nativeElement.scrollTop = targetScrollTop;
            }
          });
        }
      }
    }, 50);
  }

  ngOnDestroy() {
    this.unsubscribe.forEach((sb) => sb.unsubscribe());
  }
}
