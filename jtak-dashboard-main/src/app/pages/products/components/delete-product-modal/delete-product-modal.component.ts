import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable } from 'rxjs';
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
    public modal: NgbActiveModal
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
  }

  delete(): void {
    if (this.isBulk && this.selectedIds?.length) {
      this.service.deleteSelected(this.selectedIds).subscribe({
        next: () => this.modal.close(true),
        error: () => this.modal.dismiss(),
      });
    } else if (this.id) {
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(true),
        error: () => this.modal.dismiss(),
      });
    }
  }
}
