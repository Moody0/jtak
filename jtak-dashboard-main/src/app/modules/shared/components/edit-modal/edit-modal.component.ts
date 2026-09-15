import { Component, EventEmitter, Input, Output } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-edit-modal',
  templateUrl: './edit-modal.component.html',
})
export class EditModalComponent {
  @Input() item: any;
  @Input() itemName: string;
  @Input() moduleName: string;
  @Input() isLoading: boolean | null;
  @Input() saveDisabled: boolean;
  @Output() saveClicked = new EventEmitter();
  @Output() cancelClicked = new EventEmitter();

  constructor(public translate: TranslateService) {}

  getLocalizedModuleName(): string {
    if (!this.moduleName) return '';
    const isAr = (this.translate.currentLang || localStorage.getItem('language') || 'ar') === 'ar';
    if (!isAr) return this.moduleName;
    const map: { [key: string]: string } = {
      'banner': 'الإعلان',
      'category': 'التصنيف',
      'user': 'المستخدم',
      'merchant': 'التاجر',
      'delivery captain': 'مندوب التوصيل',
      'payment': 'الدفعة المالية',
      'product': 'المنتج',
      'notification': 'الإشعار',
      'order': 'الطلب',
    };
    return map[this.moduleName.trim().toLowerCase()] || this.moduleName;
  }

  onSaveClicked() {
    this.saveClicked.emit();
  }

  onCancelClicked() {
    this.cancelClicked.emit();
  }
}
