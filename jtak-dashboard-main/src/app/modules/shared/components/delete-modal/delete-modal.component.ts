import { Component, EventEmitter, Input, Output } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-delete-modal',
  templateUrl: './delete-modal.component.html',
})
export class DeleteModalComponent {
  @Input() isLoading: boolean | null;
  @Input() moduleName: string;
  @Input() title: string;
  @Input() deletingText: string;
  @Input() confirmationText: string;
  @Input() confirmLabel: string = 'Delete';
  @Output() deleteClicked = new EventEmitter();
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

  onDeleteClicked() {
    this.deleteClicked.emit();
  }

  onCancelClicked() {
    this.cancelClicked.emit();
  }
}
