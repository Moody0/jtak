import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { User, CaptainCompensationType } from '../../models/user.model';
import { UsersService } from '../../services/users.service';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import * as moment from 'moment';

import { FilesService } from 'src/app/modules/shared/services/files.service';

const EMPTY_USER: User = {
  id: '',
  email: '',
  phoneNumber: '',
  firstName: '',
  lastName: '',
  fullName: '',
  isActive: true,
  profilePhoto: '',
  role: 3,
  lang: 'ar',
  countryPhoneCode: '+963',
  captainCompensationType: 0,
  captainRate: 0,
};

@Component({
  selector: 'app-edit-user-modal',
  templateUrl: './edit-user-modal.component.html',
  styleUrls: ['./edit-user-modal.component.scss'],
})
export class EditUserModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: User;
  isLoading$: Observable<boolean>;
  formGroup: UntypedFormGroup;

  // Modern structured role definitions with Arabic labels and icons
  readonly availableRoles = [
    { value: 1, label: 'عميل (Customer)', icon: 'fas fa-user', desc: 'مستخدم عادي يطلب من التطبيق' },
    { value: 2, label: 'تاجر (Merchant)', icon: 'fas fa-store', desc: 'مالك أو مدير متجر مسجّل' },
    { value: 3, label: 'مندوب توصيل / كابتن (Delivery)', icon: 'fas fa-motorcycle', desc: 'سائق يقوم بتوصيل الطلبات' },
  ];

  // Backward compatible userRoles array
  userRoles = [
    ['1', 'عميل (Customer)'],
    ['2', 'تاجر (Merchant)'],
    ['3', 'مندوب توصيل / كابتن (Delivery)'],
  ];

  showPassword = false;
  isSaving=false;
  saveError='';

  constructor(
    private service: UsersService,
    private fb: UntypedFormBuilder,
    public modal: NgbActiveModal,
    public filesService: FilesService,
    private toasterService: ToastrService
  ) {}

  Number = Number;

  togglePasswordVisibility(): void {
    this.showPassword = !this.showPassword;
  }

  get captainCompensationType(): number {
    return Number(this.formGroup?.get('captainCompensationType')?.value ?? 0);
  }

  get isDeliveryRole(): boolean {
    return Number(this.formGroup?.get('role')?.value) === 3;
  }

  get isMerchantRole(): boolean {
    return Number(this.formGroup?.get('role')?.value) === 2;
  }

  getUserAvatar(): string | null {
    return this.formGroup?.get('profilePhoto')?.value || null;
  }

  getUserInitials(): string {
    const first = (this.formGroup?.get('firstName')?.value || '').trim()[0] || '';
    const last = (this.formGroup?.get('lastName')?.value || '').trim()[0] || '';
    const initials = (first + last).toUpperCase();
    return initials;
  }

  getRoleDefaultIcon(): string {
    const role = Number(this.formGroup?.get('role')?.value ?? 1);
    switch (role) {
      case 0:
        return 'fas fa-user-shield';
      case 2:
        return 'fas fa-store';
      case 3:
        return 'fas fa-motorcycle';
      default:
        return 'fas fa-user';
    }
  }

  isNameEntered(): boolean {
    const first = (this.formGroup?.get('firstName')?.value || '').trim();
    const last = (this.formGroup?.get('lastName')?.value || '').trim();
    return Boolean(first || last);
  }

  getUserDisplayName(): string {
    const first = (this.formGroup?.get('firstName')?.value || '').trim();
    const last = (this.formGroup?.get('lastName')?.value || '').trim();
    const full = `${first} ${last}`.trim();
    return full || (this.item?.id ? (this.item.fullName || 'اسم المستخدم') : 'مستخدم جديد');
  }

  getRoleBadgeInfo(): { label: string; icon: string; badgeClass: string } {
    const role = Number(this.formGroup?.get('role')?.value ?? 1);
    switch (role) {
      case 0:
        return { label: 'مدير النظام', icon: 'fas fa-user-shield', badgeClass: 'role-admin' };
      case 2:
        return { label: 'تاجر', icon: 'fas fa-store', badgeClass: 'role-merchant' };
      case 3:
        return { label: 'مندوب توصيل', icon: 'fas fa-motorcycle', badgeClass: 'role-delivery' };
      default:
        return { label: 'عميل', icon: 'fas fa-user', badgeClass: 'role-customer' };
    }
  }

  getCompensationLabel(): string {
    const type = Number(this.formGroup?.get('captainCompensationType')?.value ?? 0);
    const rate = this.formGroup?.get('captainRate')?.value ?? 0;
    switch (type) {
      case 0:
        return 'موظف براتب شهري';
      case 1:
        return `${rate} ل.س / كم`;
      case 2:
        return `نسبة ${rate}%`;
      default:
        return 'موظف براتب شهري';
    }
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = {...EMPTY_USER};
    }
  }

  loadForm() {
    const compType = Number(this.item.captainCompensationType ?? 0);
    const initialRate = this.item.captainRate !== undefined && this.item.captainRate !== null
      ? Number(this.item.captainRate)
      : (compType === 1 ? 25 : (compType === 2 ? 60 : 0));

    this.formGroup = this.fb.group({
      id: [this.item?.id],
      firstName: [this.item.firstName, [Validators.required]],
      lastName: [this.item.lastName, [Validators.required]],
      phoneNumber: [
        this.item.countryPhoneCode ? (this.item.phoneNumber || '').replace(this.item.countryPhoneCode, '') : this.item.phoneNumber,
        [Validators.required, Validators.pattern(/^[0-9]{8,15}$/)],
      ],
      countryPhoneCode: [this.item.countryPhoneCode || '+963',[Validators.required,Validators.pattern(/^\+?[1-9][0-9]{0,3}$/)]],
      email: [this.item.email, [Validators.email]],
      password: ['', this.item?.id ? [] : [Validators.required, Validators.minLength(6)]],
      isActive: [this.item.isActive !== undefined ? this.item.isActive : true],
      profilePhoto: [this.item.profilePhoto],
      role: [this.item.role !== undefined ? this.item.role : 3],
      maxCashFloat: [this.item.maxCashFloat ?? 5000000, [Validators.required, Validators.min(0)]],
      captainCompensationType: [compType],
      captainRate: [initialRate, [Validators.min(0)]],
      lang: [this.item.lang || 'ar']
    },{validators:form=>{
      const first=String(form.get('firstName')?.value || '').trim(),last=String(form.get('lastName')?.value || '').trim();
      if(!first || !last || first.length>100 || last.length>100) return {invalidNames:true};
      const password=String(form.get('password')?.value || '').trim();
      if(password && password.length<6) return {invalidPassword:true};
      const limit=Number(form.get('maxCashFloat')?.value),rate=Number(form.get('captainRate')?.value),type=Number(form.get('captainCompensationType')?.value);
      const validMoney=(value:number)=>Number.isFinite(value) && value>=0 && value<=1000000000 && Math.abs(value*100-Math.round(value*100))<0.000001;
      if(!validMoney(limit) || !validMoney(rate) || ![0,1,2].includes(type) || (type===2 && rate>100))return {invalidCompensation:true};
      return null;
    }});
  }

  onCompensationTypeChange(type: number): void {
    const numericType = Number(type);
    this.formGroup.get('captainCompensationType')?.setValue(numericType);
    const currentRate = Number(this.formGroup.get('captainRate')?.value || 0);

    if (numericType === 0) {
      this.formGroup.get('captainRate')?.setValue(0);
    } else if (numericType === 1 && currentRate === 0) {
      this.formGroup.get('captainRate')?.setValue(25);
    } else if (numericType === 2 && (currentRate === 0 || currentRate > 100)) {
      this.formGroup.get('captainRate')?.setValue(60);
    }
  }

  onFileUploaded(filesIds: string[], key: string) {
    this.formGroup.patchValue({
      [key]: filesIds.join(",")
    });
  }

  onFileDelete(key: string) {
    this.formGroup.patchValue({
      [key]: '',
    });
  }

  save() {
    if(this.isSaving) return;
    if(this.formGroup.invalid){this.formGroup.markAllAsTouched();this.saveError='راجع البيانات. النسبة بين صفر و100% والمبالغ بحد أقصى منزلتين عشريتين، وكلمة المرور 6 أحرف على الأقل.';return;}
    const formValues: any = { ...this.formGroup.value };

    if (Number(formValues.role) === 3) {
      formValues.captainCompensationType = Number(formValues.captainCompensationType ?? 0);
      formValues.captainRate = Number(formValues.captainRate ?? 0);
      if (formValues.captainCompensationType === 0) {
        formValues.captainRate = 0;
      }
    } else {
      formValues.captainCompensationType = 0;
      formValues.captainRate = 0;
    }

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: User) {
    if(this.isSaving) return;
    this.isSaving=true;this.saveError='';this.formGroup.disable();
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تم إنشاء المستخدم.');
          this.modal.close();
        })
      )
      .subscribe({error:error=>this.failed(error)});
  }

  edit(formValues: User) {
    if(this.isSaving) return;
    this.isSaving=true;this.saveError='';this.formGroup.disable();
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('تم حفظ بيانات المستخدم.');
          this.modal.close();
        })
      )
      .subscribe({error:error=>this.failed(error)});
  }

  private failed(error:any):void {
    this.isSaving=false;this.formGroup.enable();
    const body=error?.error;
    this.saveError=typeof body==='string' ? body : body?.errorDescription || body?.message || (Array.isArray(body?.errors) ? body.errors.map((e:any)=>e.description).join('، ') : '') || 'تعذر حفظ المستخدم. تحقق من البيانات والسجل قبل إعادة المحاولة.';
    this.toasterService.error(this.saveError);
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
