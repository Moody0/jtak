import {
  Component,
  OnInit,
  Input,
  OnDestroy,
  ChangeDetectorRef,
} from '@angular/core';
import { FormArray, UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
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
  formGroup: UntypedFormGroup;
  deliviries: User[] = [];

  constructor(
    private service: UsersService,
    private fb: UntypedFormBuilder,
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
      uid: [this.item.deliveryId === '00000000-0000-0000-0000-000000000000' ? null : this.item.deliveryId, Validators.required],
    });
  }

  getDriverDisplay(driver: User): string {
    if (!driver) return 'Unknown Driver';
    const name = driver.fullName && !driver.fullName.includes('?') ? driver.fullName : '';
    const phone = driver.phoneNumber || '';
    if (name && phone) return `${name} (${phone})`;
    return name || phone || driver.email || 'Delivery Driver';
  }

  unassign() {
    this.formGroup.get('uid')?.setValue('00000000-0000-0000-0000-000000000000');
    this.saved();
  }

  saved() {
    const id = this.formGroup.get('id')?.value;
    const uid = this.formGroup.get('uid')?.value || '00000000-0000-0000-0000-000000000000';

    this.subs.sink = this.orderService
      .setDelievry(id, uid)
      .subscribe({
        next: () => {
          this.toasterService.success(uid === '00000000-0000-0000-0000-000000000000' ? 'Order returned to Available Pool' : 'Delivery Captain Updated');
          this.modal.close();
        },
        error: (err: any) => {
          const errMsg = err?.error?.title || err?.error?.detail || err?.error?.message || err?.message || 'تعذر تعيين مندوب التوصيل.';
          this.toasterService.error(errMsg);
        }
      });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
