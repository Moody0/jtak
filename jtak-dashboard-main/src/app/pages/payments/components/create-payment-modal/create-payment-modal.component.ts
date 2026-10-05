import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Subscription } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { Payment } from '../../models/payments.model';
import { paymentsService } from '../../services/payments.service';
import { MerchantsService } from 'src/app/pages/merchant/services/merchants.service';
import { DeliveriesService } from '../../services/deliveries.service';

@Component({selector:'app-create-payment-modal',templateUrl:'./create-payment-modal.component.html',styleUrls:['./create-payment-modal.component.scss']})
export class CreatePaymentModalComponent implements OnInit, OnDestroy {
  private subs = new Subscription();
  private balanceRequest?: Subscription;
  private requestKey = '';
  private submittedPayload = '';
  @Input() item: Payment;
  merchants: {id:string; merchantId:number; fullName:string}[] = [];
  deliveries: any[] = [];
  formGroup: UntypedFormGroup;
  merchantBalance: number | null = null;
  deliveryBalance: number | null = null;
  isSaving = false;
  isLoading = false;
  loadingBalances = false;
  loadError = '';

  constructor(private paymentsService:paymentsService,private fb:UntypedFormBuilder,public modal:NgbActiveModal,
    private toasterService:ToastrService,private merchantsService:MerchantsService,private deliveriesService:DeliveriesService) {}

  ngOnInit(): void {
    this.item = this.item || {id:'',toUser:'',byUser:'',toUserId:'',byUserId:'',amount:0,newBalance:0,handoverDate:'',createdDate:''};
    this.formGroup=this.fb.group({toUser:[null,Validators.required],byUser:[null,Validators.required],amount:[this.item.amount,[Validators.required,Validators.min(0.01)]]});
    this.isLoading=true;
    this.subs.add(this.merchantsService.getAllMerchants().subscribe({
      next: items=>{this.merchants=(items || []).filter(m=>!!m.ownerId).map(m=>({id:m.ownerId,merchantId:Number(m.id),fullName:m.title}));this.isLoading=false;},
      error:()=>{this.isLoading=false;this.loadError='تعذر تحميل المتاجر. أعد فتح النافذة وحاول مرة أخرى.';}
    }));
    this.subs.add(this.deliveriesService.getDeliveries().subscribe({next:(items:any)=>this.deliveries=items || [],error:()=>this.loadError='تعذر تحميل المندوبين. أعد فتح النافذة وحاول مرة أخرى.'}));
  }

  get canSave(): boolean {
    const amount=Number(this.formGroup?.get('amount')?.value);
    return !!this.formGroup && this.formGroup.valid && !this.isSaving && !this.isLoading && !this.loadingBalances && !this.loadError &&
      Number.isFinite(amount) && amount>0 && Math.abs(amount*100-Math.round(amount*100))<0.000001 &&
      this.deliveryBalance !== null && this.merchantBalance !== null && amount <= this.deliveryBalance && amount <= this.merchantBalance;
  }

  save(): void {
    if(!this.canSave){this.formGroup.markAllAsTouched();this.toasterService.warning('أدخل مبلغاً صحيحاً لا يتجاوز عهدة المندوب أو مستحقات المتجر المتاحة، بحد أقصى منزلتين عشريتين.');return;}
    const values=this.formGroup.value;
    const payload:any={byUserId:values.byUser.id,toUserId:values.toUser.id,merchantId:values.toUser.merchantId,amount:Number(values.amount)};
    const snapshot=JSON.stringify(payload);
    if(snapshot!==this.submittedPayload){this.submittedPayload=snapshot;this.requestKey=`web-${Date.now()}-${Math.random().toString(36).slice(2,14)}`;}
    payload.requestKey=this.requestKey;
    this.isSaving=true;this.formGroup.disable();
    this.subs.add(this.paymentsService.create(payload).subscribe({
      next:()=>{this.toasterService.success('تم إنشاء الدفعة. لن تُخصم من الحسابات إلا بعد تأكيد التاجر لاستلامها');this.modal.close(true);},
      error:err=>{this.isSaving=false;this.formGroup.enable();this.toasterService.error(err?.error?.message || err?.error?.error || 'تعذر تأكيد تسجيل الدفعة. حدّث السجل للتحقق قبل إعادة المحاولة.');}
    }));
  }

  changedMerchant(_:any): void {this.loadBalances();}
  changedDelivery(_:any): void {this.loadBalances();}
  private loadBalances(): void {
    this.balanceRequest?.unsubscribe();this.merchantBalance=this.deliveryBalance=null;this.loadingBalances=true;
    const values=this.formGroup.value;
    this.balanceRequest=this.paymentsService.availableBalances(values.byUser?.id,values.toUser?.merchantId).subscribe({
      next:balances=>{this.merchantBalance=balances.merchantBalance;this.deliveryBalance=balances.deliveryBalance;this.loadingBalances=false;},
      error:()=>{this.loadingBalances=false;this.toasterService.error('تعذر تحميل الأرصدة المتاحة. أعد اختيار المتجر والمندوب.');}
    });
  }
  ngOnDestroy(): void {this.balanceRequest?.unsubscribe();this.subs.unsubscribe();}
}
