import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable, forkJoin, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { ToastrService } from 'ngx-toastr';
import { ProductsService } from '../../services/products.service';

@Component({
  selector: 'app-delete-product-modal',
  templateUrl: './delete-product-modal.component.html',
})
export class DeleteProductModalComponent implements OnInit {
  @Input() id: number;
  @Input() isBulk = false;
  @Input() count = 0;
  @Input() selectedIds: number[] = [];

  isLoading$: Observable<boolean>;

  constructor(
    private service: ProductsService,
    public modal: NgbActiveModal,
    private toaster: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
  }

  delete(): void {
    if (this.isBulk && this.selectedIds?.length) {
      this.service.deleteSelected(this.selectedIds).pipe(
        catchError(() => {
          // If bulk endpoint fails, fallback to parallel individual deletes
          return forkJoin(
            this.selectedIds.map((id) =>
              this.service.delete(id).pipe(
                map(() => true),
                catchError(() => of(false))
              )
            )
          ).pipe(
            map((results) => {
              const allSuccess = results.every(Boolean);
              if (!allSuccess) {
                throw new Error('Some items could not be deleted');
              }
              return true;
            })
          );
        })
      ).subscribe({
        next: () => this.modal.close(true),
        error: (err) => {
          this.toaster.info(
            'تنبيه: المنتجات المرتبطة بطلبات أو وجبات مخزون سابقة لا يمكن حذفها من قاعدة البيانات منعاً لتلف السجلات، يرجى استخدام خيار "تعطيل" بدلاً من الحذف.'
          );
          this.modal.dismiss(err);
        },
      });
    } else if (this.id) {
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(true),
        error: (err) => {
          this.toaster.info(
            'تنبيه: هذا المنتج مرتبط بسجلات طلبات أو مخزون سابقة في النظام. يرجى استخدام خيار "تعطيل" لإخفائه عن العملاء بدلاً من حذفه نهائياً.'
          );
          this.modal.dismiss(err);
        },
      });
    }
  }
}
