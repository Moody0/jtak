import { Component, Input, OnInit } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
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
  deleting = false;

  constructor(
    public service: MerchantsService,
    public modal: NgbActiveModal, private toaster: ToastrService) { }

  ngOnInit(): void {
  }

  delete(): void {
    if (this.deleting) return;
    if (this.id) {
      this.deleting = true;
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(true),
        error: (error) => {
          this.deleting = false;
          const body = error?.error;
          this.toaster.error(Array.isArray(body?.errors) ? body.errors.join('، ') : 'تعذر الحذف. حاول مرة أخرى.');
        },
      });
    }
  }
}
