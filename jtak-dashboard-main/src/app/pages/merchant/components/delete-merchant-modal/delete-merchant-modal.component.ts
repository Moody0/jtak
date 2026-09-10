import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Merchant } from '../../models/merchant.model';
import { MerchantsService } from '../../services/merchants.service';

@Component({
  selector: 'app-delete-merchant-modal',
  templateUrl: './delete-merchant-modal.component.html',
  styles: [
  ]
})
export class DeleteMerchantModalComponent implements OnInit {
  @Input() id: number;

  constructor(
    public service: MerchantsService,
    public modal: NgbActiveModal) { }

  ngOnInit(): void {
  }

  delete() {
    if (this.id) {
      this.service
          .delete(this.id).subscribe({
            next: () => this.modal.close(),
            error: () => this.modal.dismiss()
          });
    }
  }
}
