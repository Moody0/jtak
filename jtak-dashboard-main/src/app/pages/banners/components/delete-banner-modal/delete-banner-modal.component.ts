import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { ToastrService } from 'ngx-toastr';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { BannersService } from '../../services/banners.service';


@Component({
  selector: 'app-delete-banner-modal',
  templateUrl: './delete-banner-modal.component.html',
  styles: [
  ]
})
export class DeleteBannerModalComponent implements OnInit, OnDestroy {

  private subs = new SubSink();
  @Input() id: string;
  isLoading$: Observable<boolean>;

  constructor(private bannersService: BannersService, public modal: NgbActiveModal, private toasterService: ToastrService) { }

  ngOnInit(): void {
    this.isLoading$ = this.bannersService.isLoading$;
  }

  delete() {
    this.subs.sink = this.bannersService.delete(this.id).pipe(
      tap(() => {
        this.toasterService.success('User Deleted');
        this.modal.close();
      }),
    ).subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

}
