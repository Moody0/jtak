import { ChangeDetectionStrategy, Component, Inject, OnInit } from '@angular/core';
import { TranslationService } from './modules/i18n';
// language list
import { locale as arLang } from './modules/i18n/vocabs/ar';
import { locale as enLang } from './modules/i18n/vocabs/en';
import { locale as chLang } from './modules/i18n/vocabs/ch';
import { locale as esLang } from './modules/i18n/vocabs/es';
import { locale as jpLang } from './modules/i18n/vocabs/jp';
import { locale as deLang } from './modules/i18n/vocabs/de';
import { locale as frLang } from './modules/i18n/vocabs/fr';
import { SplashScreenService } from './_metronic/partials';
import { NavigationEnd, Router } from '@angular/router';
import { DOCUMENT } from '@angular/common';
import { Subscription } from 'rxjs';

@Component({
  // tslint:disable-next-line:component-selector
  selector: 'body[root]',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent implements OnInit {
  // Read more: => https://brianflove.com/2016/12/11/anguar-2-unsubscribe-observables/
  private unsubscribe: Subscription[] = [];
  
  constructor(
    private translationService: TranslationService,
    private splashScreenService: SplashScreenService,
    private router: Router,
    //private tableService: TableExtendedService,
    @Inject(DOCUMENT) private document: Document) {
    // register translations
    this.translationService.loadTranslations(
      arLang,
      enLang,
      chLang,
      esLang,
      jpLang,
      deLang,
      frLang
    );
  }

  ngOnInit() {
    this.setLayoutDirection(this.translationService.getSelectedLanguage());

    const routerSubscription = this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) {
        // clear filtration paginations and others
        // this.tableService.setDefaults();
        // hide splash screen
        this.splashScreenService.hide();

        // scroll to top on every route change
        window.scrollTo(0, 0);

        // to display back the body content
        setTimeout(() => {
          document.body.classList.add('page-loaded');
        }, 500);
      }
    });
    this.unsubscribe.push(routerSubscription);

    // if (this.authService.isLoggedIn()) {
    //   this.userService.getMyProfile().subscribe();
    // }}
  }
  
  setLayoutDirection(lang: string) {
    this.translationService.updateDirection(lang);
  }

  ngOnDestroy() {
    this.unsubscribe.forEach((sb) => sb.unsubscribe());
  }
}
