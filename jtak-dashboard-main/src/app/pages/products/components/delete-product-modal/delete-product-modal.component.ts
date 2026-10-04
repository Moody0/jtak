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
  deleting = false;

  constructor(
    private service: ProductsService,
    public modal: NgbActiveModal,
    private toaster: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
  }

  delete(): void {
    if (this.deleting) return;
    const ids = this.isBulk ? this.selectedIds : [this.id];
    if (!ids?.length || ids.some(id => !id)) return;
    this.deleting = true;
    const request = this.isBulk ? this.service.deleteSelected(ids) : this.service.delete(this.id);
    request.subscribe({
      next: () => this.modal.close(true),
      error: (error) => {
        this.deleting = false;
        const body = error?.error;
        this.toaster.error(Array.isArray(body?.errors) ? body.errors.join('، ') : 'تعذر حذف المنتج. حاول مرة أخرى.');
      }
    });
  }

}
