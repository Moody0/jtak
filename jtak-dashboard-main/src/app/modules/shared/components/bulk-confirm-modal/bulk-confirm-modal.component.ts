import { Component, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable, Subscription } from 'rxjs';
import { finalize } from 'rxjs/operators';

@Component({
  selector: 'app-bulk-confirm-modal',
  templateUrl: './bulk-confirm-modal.component.html',
})
export class BulkConfirmModalComponent implements OnDestroy {
  private request?: Subscription;
  errorMessage = '';
  @Input() count = 0;
  @Input() itemLabel = 'records';
  @Input() actionLabel = 'Delete';
  @Input() description = 'This action cannot be undone.';
  @Input() action: () => Observable<unknown>;
  isLoading = false;
  hasError = false;

  constructor(public modal: NgbActiveModal) {}

  confirm(): void {
    if (!this.action || this.isLoading) return;
    this.isLoading = true;
    this.hasError = false;
    this.request = this.action().pipe(finalize(() => this.isLoading = false)).subscribe({
      next: () => this.modal.close(true),
      error: error => { this.hasError = true; this.errorMessage = error?.error?.errorDescription || error?.error?.message || 'تعذر تأكيد نجاح الإجراء. حدّث البيانات للتحقق من الحالة قبل إعادة المحاولة.'; },
    });
  }
  ngOnDestroy(): void { this.request?.unsubscribe(); }
}
