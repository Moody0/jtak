import { Component, OnDestroy, OnInit } from '@angular/core';
import { TranslationService } from '../i18n';

@Component({
  selector: '<body[root]>',
  templateUrl: './auth.component.html',
  styleUrls: ['./auth.component.scss'],
})
export class AuthComponent implements OnInit, OnDestroy {
  today: Date = new Date();
  currentLanguage: string;

  constructor(private translationService: TranslationService) {
    this.currentLanguage = this.translationService.getSelectedLanguage();
  }

  ngOnInit(): void {
    document.body.classList.add('bg-white');
  }

  ngOnDestroy() {
    document.body.classList.remove('bg-white');
  }

  setLanguage(language: 'ar' | 'en'): void {
    this.currentLanguage = language;
    this.translationService.setLanguage(language);
  }
}
