import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { ToastrService } from 'ngx-toastr';
import { Observable } from 'rxjs';
import { BannersService } from '../../services/banners.service';


@Component({
  selector: 'app-delete-banner-modal',
  templateUrl: './delete-banner-modal.component.html',
  styles: [
  ]
})
export class DeleteBannerModalComponent implements OnInit, OnDestroy {

  private subs = new SubSink();
  deleting = false;
  @Input() id: string;
  isLoading$: Observable<boolean>;

  constructor(private bannersService: BannersService, public modal: NgbActiveModal, private toasterService: ToastrService) { }

  ngOnInit(): void {
    this.isLoading$ = this.bannersService.isLoading$;
  }

  delete() {
    if (this.deleting) return;
    this.deleting = true;
    this.subs.sink = this.bannersService.delete(this.id).subscribe({
      next: () => { this.toasterService.success('تم حذف الإعلان'); this.modal.close(true); },
      error: err => { this.deleting = false; this.toasterService.error(typeof err?.error === 'string' ? err.error : 'تعذر حذف الإعلان، حاول مرة أخرى'); }
    });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

}
