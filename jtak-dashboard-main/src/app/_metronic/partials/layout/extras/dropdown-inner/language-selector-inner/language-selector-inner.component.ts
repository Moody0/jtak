import { Component, HostBinding, OnInit } from '@angular/core';
import { NavigationStart, Router } from '@angular/router';
import { filter } from 'rxjs/operators';
import { TranslationService } from '../../../../../../modules/i18n/translation.service';

interface LanguageFlag {
  lang: string;
  name: string;
  flag: string;
  active?: boolean;
}

@Component({
  selector: 'app-language-selector-inner',
  templateUrl: './language-selector-inner.component.html',
  styleUrls: ['./language-selector-inner.component.scss'],
})
export class LanguageSelectorComponent implements OnInit {
  @HostBinding('attr.data-kt-menu') dataKtMenu = 'true';

  toolbarButtonMarginClass = 'ms-1 ms-lg-3';
  toolbarButtonHeightClass = 'w-30px h-30px w-md-40px h-md-40px';
  toolbarUserAvatarHeightClass = 'symbol-30px symbol-md-40px';
  toolbarButtonIconSizeClass = 'svg-icon-1';
  language: LanguageFlag;
  languages: LanguageFlag[] = [
    {
      lang: 'en',
      name: 'English',
      flag: './assets/media/flags/united-states.svg',
    },
    {
      lang: 'ar',
      name: 'العربية',
      flag: './assets/media/flags/syria.svg',
    },
  ];
  constructor(
    private translationService: TranslationService,
    private router: Router
  ) {}

  ngOnInit() {
    this.setSelectedLanguage();
    this.router.events
      .pipe(filter((event) => event instanceof NavigationStart))
      .subscribe((event) => {
        this.setSelectedLanguage();
      });
  }

  setLanguageWithRefresh(lang:string) {
    this.setLanguage(lang);
    window.location.reload();
  }

  setLanguage(lang:string) {
    this.languages.forEach((language: LanguageFlag) => {
      if (language.lang === lang) {
        language.active = true;
        this.language = language;
      } else {
        language.active = false;
      }
    });
    this.translationService.setLanguage(lang);
  }

  setSelectedLanguage(): any {
    this.setLanguage(this.translationService.getSelectedLanguage());
  }
}
