import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ProductsService } from '../../services/products.service';

@Component({
  selector: 'app-delete-product-modal',
  templateUrl: './delete-product-modal.component.html',
  styles: [
  ]
})
export class DeleteProductModalComponent implements OnInit {
  @Input() id: number;

  constructor(
    private service: ProductsService,
    public modal: NgbActiveModal) { }

  ngOnInit(): void {
  }

  delete() {
    if (this.id) {
      this.service
          .delete(this.id).subscribe(x => this.modal.dismiss());
    }
  }
}
