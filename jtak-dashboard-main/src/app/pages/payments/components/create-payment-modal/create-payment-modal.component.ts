import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Payment } from '../../models/payments.model';
import { paymentsService } from '../../services/payments.service';
import { MerchantsService } from '../../services/merchants.service';
import { Merchant } from '../../models/merchant.model'
import { DeliveriesService } from '../../services/deliveries.service';
import { Deliver } from '../../models/deliver.model';
import { UsersService } from 'src/app/pages/users/services/users.service';

const EMPTY_PAYMENT: Payment = {
  id: '',
  toUserId: '',
  toUser: '',
  byUserId: '',
  byUser: '',
  amount: 0,
  newBalance: 0,
  handoverDate: '',
  createdDate: '',
};

@Component({
  selector: 'app-create-payment-modal',
  templateUrl: './create-payment-modal.component.html',
})
export class CreatePaymentModalComponent implements OnInit {
  private subs = new SubSink();
  isLoading: boolean;
  merchants: Merchant[] = [];
  deliveries: Deliver[] = [];
  @Input() item: Payment;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  merchantBalance:number = 0;
  deliveryBalance:number = 0;
  constructor(
    private usersService: UsersService,
    private paymentsService: paymentsService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService,
    public merchantsService: MerchantsService,
    public deliveriesService: DeliveriesService
  ) { }

  ngOnInit(): void {
    this.isLoading$ = this.paymentsService.isLoading$;
    this.merchantsService.getMerchants().subscribe((resulte: any) => {
      this.merchants = resulte
    })
    this.deliveriesService.getDeliveries().subscribe((resulte: any) => {
      this.deliveries = resulte
    })
    this.subs.sink = this.paymentsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_PAYMENT;
    }
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      toUser: [this.item.toUser, [Validators.required]],
      byUser: [this.item.byUser, [Validators.required]],
      amount: [this.item.amount, [Validators.required]],
      //newBalance: [this.item.newBalance, [Validators.required]],
      //handoverDate: [this.item.handoverDate, [Validators.required]]
    });
  }

  onFileUploaded(filesIds: string[], key: string) {
    var oldVal = this.formGroup.controls[key].value;
    this.formGroup.patchValue({
      key: oldVal + filesIds.join(",")
    });
  }

  onFileDelete(key: string) {
    this.formGroup.patchValue({
      [key]: '',
    });
  }

  save() {
    const formValues = {
      id: this.formGroup.value.id,
      toUserId: this.formGroup.value.toUser.id,
      toUser: this.formGroup.value.toUser.fullName,
      byUserId: this.formGroup.value.byUser.id,
      byUser: this.formGroup.value.byUser.fullName,
      amount: this.formGroup.value.amount,
      newBalance: 0,
      handoverDate: null,
      createdDate: null,
      //newBalance: this.formGroup.value.newBalance,
      //handoverDate: this.formGroup.value.handoverDate
    }
    delete formValues.id;
    this.create(formValues);
    console.log(formValues);


  }


  create(formValues: Payment) {
    this.subs.sink = this.paymentsService
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Payment Added');
          this.modal.close();
        })
      )
      .subscribe();
  }

  changedMerchant(e: Merchant) {
    this.merchantBalance = 0;
    this.usersService.getBalance(e.id).subscribe(b=>this.merchantBalance = b.amount);
  }
  changedDelivery(e: Deliver) {
    this.deliveryBalance = 0;
    this.usersService.getBalance(e.id).subscribe(b=>this.deliveryBalance = b.amount);

  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}

