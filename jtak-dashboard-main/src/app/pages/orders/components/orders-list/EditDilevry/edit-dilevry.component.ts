import {
  Component,
  OnInit,
  Input,
  OnDestroy,
  ChangeDetectorRef,
} from '@angular/core';
import { FormArray, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable, pipe } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Order } from '../../../models/orders.model';
import { UsersService } from 'src/app/pages/users/services/users.service';
import { User } from 'src/app/pages/users/models/user.model';
import { OrdersService } from '../../../services/orders.service';

@Component({
  selector: 'app-edit-dilevry',
  templateUrl: './edit-dilevry.component.html',
  styleUrls: ['./edit-dilevry.component.scss'],
})
export class EditDilevry implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Order;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  deliviries: User[] = [];

  constructor(
    private service: UsersService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService,
    private orderService: OrdersService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    this.service.getDeliveries().subscribe((res) => {
      this.deliviries = res;
    });
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item.id],
      uid: [this.item.deliveryId],
    });
  }

  saved() {
    this.subs.sink = this.orderService
      .setDelievry(
        this.formGroup.get('id')?.value,
        this.formGroup.get('uid')?.value
      )
      .pipe(
        tap(() => {
          this.toasterService.success('Dilevry Updated');
          this.modal.close();
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
