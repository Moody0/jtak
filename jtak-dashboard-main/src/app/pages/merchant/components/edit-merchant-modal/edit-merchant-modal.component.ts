import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { UntypedFormBuilder, UntypedFormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable, of } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap, catchError, finalize } from 'rxjs/operators';
import { Merchant } from '../../models/merchant.model';
import { MerchantsService } from '../../services/merchants.service';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import { UserModel } from 'src/app/modules/auth';
import { UsersService } from 'src/app/pages/users/services/users.service';
import { User } from 'src/app/pages/users/models/user.model';
import { HttpClient } from '@angular/common/http';

import { FilesService } from 'src/app/modules/shared/services/files.service';

const EMPTY_Merchant: Merchant = {  
  id: 0,
  title: '',
  shortDescription: '',
  description: '',
  ibaN1Title: '',
  ibaN1: '',
  phone1: '',
  phone2: '',
  address: '',
  shippingCoverageInMeters: 1000,
  profitOutOfMerchantPricePercent: 20,
  lat: 34.7324,
  lng: 36.7137,
  active: false,
  merchantKind: 0,
  deliveryTime: '20-30 دقيقة',
  deliveryFee: 50,
  minOrderAmount: 150,
  workingHours: 'حتى 3 ص',
  ownerId: '',
  owner: '',
  photo: ''
};

@Component({
  selector: 'app-edit-merchant-modal',
  templateUrl: './edit-merchant-modal.component.html',
  styleUrls: ['./edit-merchant-modal.component.scss'],
})
export class EditMerchantModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Merchant;
  @Input() initialMerchantKind: number | null = null;

  get isWarehouseRecord(): boolean {
    return Number(this.initialMerchantKind ?? this.formGroup?.get('merchantKind')?.value ?? this.item?.merchantKind) === 4;
  }

  get isWarehouseCreation(): boolean {
    return this.initialMerchantKind === 4 && !this.item?.id;
  }
  merchantUsers: User[] = [];
  loadingUsers = false;
  creatingMerchantAccount = false;
  showAccountCreation = false;
  accountFirstName = '';
  accountLastName = '';
  accountPhone = '';
  accountPassword = '';
  passwordResetting = false;
  newMerchantPassword = '';
  confirmMerchantPassword = '';
  isLoading$: Observable<boolean>;
  formGroup: UntypedFormGroup;
  isSaving = false;
  userRoles = Object.entries(AppUserRoleMap);
  zoom = 10;
  get mapAvailable(): boolean { return !!(window as any).google?.maps?.Map; }
  center: google.maps.LatLngLiteral;
  marker: any;
  options: google.maps.MapOptions = {
    // mapTypeId: 'hybrid',
    zoomControl: true,
    scrollwheel: true,
    disableDoubleClickZoom: true,
    maxZoom: 15,
    minZoom: 8,
  };

  commissionPresets: number[] = [5, 10, 15, 20, 25];
  coveragePresets: number[] = [1000, 2000, 3000, 5000, 10000];
  deliveryTimePresets: string[] = ['15-25 دقيقة', '20-30 دقيقة', '25-40 دقيقة', '30-45 دقيقة', '40-60 دقيقة'];
  deliveryFeePresets: number[] = [0, 30, 50, 70, 100];
  minOrderPresets: number[] = [100, 150, 200, 250, 300, 500];
  workingHoursPresets: string[] = ['حتى 12 ص', 'حتى 1 ص', 'حتى 2 ص', 'حتى 3 ص', '24 ساعة'];

  setDeliveryTime(val: string): void {
    this.formGroup.patchValue({ deliveryTime: val });
  }

  setDeliveryFee(val: number): void {
    this.formGroup.patchValue({ deliveryFee: val });
  }

  setMinOrder(val: number): void {
    this.formGroup.patchValue({ minOrderAmount: val });
  }

  setWorkingHours(val: string): void {
    this.formGroup.patchValue({ workingHours: val });
  }

  userSearchFn = (term: string, item: User) => {
    if (!term) return true;
    const cleanTerm = term.trim().toLowerCase().replace(/[+\s-]/g, '');
    
    // Check fullName
    const fullName = (item.fullName || '').toLowerCase();
    if (fullName.includes(term.trim().toLowerCase())) return true;
    
    // Check firstName and lastName
    const first = (item.firstName || '').toLowerCase();
    const last = (item.lastName || '').toLowerCase();
    if (first.includes(term.trim().toLowerCase()) || last.includes(term.trim().toLowerCase())) return true;

    // Check email
    const email = (item.email || '').toLowerCase();
    if (email.includes(term.trim().toLowerCase())) return true;

    // Check phoneNumber (raw, with/without country code, with/without leading zero)
    const phone = (item.phoneNumber || '').replace(/[+\s-]/g, '');
    if (phone.includes(cleanTerm)) return true;

    // E.g. searching 09... when stored as +9639...
    if (cleanTerm.startsWith('0') && phone.includes(cleanTerm.substring(1))) return true;
    if (cleanTerm.startsWith('963') && phone.includes(cleanTerm)) return true;
    if (phone.startsWith('963') && cleanTerm.length >= 4 && phone.includes(cleanTerm)) return true;

    return false;
  };

  constructor(
    private service: MerchantsService,
    private userService: UsersService,
    private fb: UntypedFormBuilder,
    public modal: NgbActiveModal,
    public filesService: FilesService,
    private toasterService: ToastrService,
    private cdk: ChangeDetectorRef
  ) {}

  setCommission(val: number): void {
    this.formGroup.get('profitOutOfMerchantPricePercent')?.setValue(val);
  }

  setCoverage(val: number): void {
    this.formGroup.get('shippingCoverageInMeters')?.setValue(val);
  }

  setMerchantKind(val: number): void {
    const defaults: Record<number, string> = {
      0: 'مطعم ومأكولات متنوعة', 1: 'سوبرماركت ومواد غذائية',
      2: 'صيدلية ومنتجات صحية', 3: 'متجر متنوع', 4: 'مستودع مركزي لتخزين وتجهيز المنتجات'
    };
    const desc = String(this.formGroup.get('shortDescription')?.value ?? '').trim();
    if (!desc || Object.values(defaults).includes(desc)) {
      this.formGroup.get('shortDescription')?.setValue(defaults[val]);
    }
    this.formGroup.get('merchantKind')?.setValue(val);
  }

  getStorePhoto(): string | null {
    return this.formGroup?.get('photo')?.value || null;
  }

  getSelectedMerchantOwner(): User | undefined {
    const ownerId = this.formGroup?.get('ownerId')?.value || this.item?.ownerId;
    return ownerId ? this.merchantUsers.find((user) => user.id === ownerId) : undefined;
  }

  createMerchantAccount(): void {
    const firstName = this.accountFirstName.trim();
    const lastName = this.accountLastName.trim();
    const phone = this.normalizePhone(this.accountPhone);
    const canonicalPhone = /^09\d{8}$/.test(phone) ? `+963${phone.substring(1)}` : '';
    const password = this.accountPassword;
    if (!firstName || !lastName || !canonicalPhone || password.length < 6) {
      this.toasterService.error('أدخل الاسم الأول والأخير ورقم موبايل سوري صحيح وكلمة مرور من 6 أحرف على الأقل.');
      return;
    }

    this.creatingMerchantAccount = true;
    // The API DTO's Id is a non-nullable Guid. Omitting it lets the server
    // apply its default; sending an empty string fails JSON Guid conversion.
    const account = {
      firstName, lastName, fullName: `${firstName} ${lastName}`,
      phoneNumber: canonicalPhone, countryPhoneCode: '+963', email: '',
      password, role: 2, isActive: true, lang: 'ar'
    } as User;
    this.subs.sink = this.userService.create(account).pipe(
      tap((id) => {
        this.merchantUsers.push({ ...account, id, password: undefined, phoneNumber: canonicalPhone });
        this.formGroup.patchValue({ ownerId: id, ownerName: account.fullName, owner: account.fullName });
        this.accountPassword = '';
        this.showAccountCreation = false;
        this.toasterService.success('تم إنشاء حساب التاجر وربطه. احفظ بيانات المتجر لإكمال الربط.');
        this.cdk.detectChanges();
      }),
      catchError((error) => {
        const message = error?.error?.errorDescription || error?.error?.error ||
          error?.error?.errors?.[0]?.description || 'تعذر إنشاء حساب التاجر.';
        this.toasterService.error(message);
        return of(null);
      }),
      finalize(() => { this.creatingMerchantAccount = false; this.cdk.detectChanges(); })
    ).subscribe();
  }

  resetMerchantPassword(): void {
    const owner = this.getSelectedMerchantOwner();
    const password = this.newMerchantPassword.trim();
    const confirmation = this.confirmMerchantPassword.trim();

    if (!owner) {
      this.toasterService.error('لا يوجد حساب تاجر مرتبط بهذا المتجر.');
      return;
    }
    if (password.length < 6) {
      this.toasterService.error('يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.');
      return;
    }
    if (password !== confirmation) {
      this.toasterService.error('كلمتا المرور غير متطابقتين.');
      return;
    }

    this.passwordResetting = true;
    this.subs.sink = this.userService
      .resetMerchantPassword(owner.id, password)
      .pipe(
        tap(() => {
          this.newMerchantPassword = '';
          this.confirmMerchantPassword = '';
          this.toasterService.success(`تم تغيير كلمة مرور حساب ${owner.fullName || 'التاجر'}.`);
          this.cdk.detectChanges();
        }),
        catchError((error) => {
          const errors = error?.error?.errors;
          const identityErrors = Array.isArray(errors)
            ? errors.map((item) => item?.description).filter(Boolean).join(' ')
            : errors
              ? Object.values(errors)
                  .map((value) => Array.isArray(value) ? value.join(' ') : String(value))
                  .join(' ')
              : '';
          const description = identityErrors || error?.error?.errorDescription || error?.error?.error || error?.error?.message;
          this.toasterService.error(
            description || 'تعذر تغيير كلمة المرور، يرجى التحقق من البيانات والمحاولة مجدداً.'
          );
          return of(null);
        }),
        finalize(() => {
          this.passwordResetting = false;
          this.cdk.detectChanges();
        })
      )
      .subscribe();
  }

  getKindInfo(): { label: string; icon: string; emoji: string } {
    const kind = Number(this.formGroup?.get('merchantKind')?.value ?? 0);
    switch (kind) {
      case 1:
        return { label: 'سوبرماركت / بقالية', icon: 'fas fa-shopping-basket', emoji: '🛒' };
      case 2:
        return { label: 'صيدلية', icon: 'fas fa-prescription-bottle-alt', emoji: '💊' };
      case 3:
        return { label: 'أخرى', icon: 'fas fa-store', emoji: '🏪' };
      case 4:
        return { label: 'مستودع مركزي', icon: 'fas fa-warehouse', emoji: '🏬' };
      default:
        return { label: 'مطعم', icon: 'fas fa-utensils', emoji: '🍽️' };
    }
  }

  onImageError(event: any): void {
    event.target.src = './assets/media/svg/files/blank-image.svg';
  }

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
  }

  loadItem() {
    if (!this.item) {
      this.item = { ...EMPTY_Merchant };
    }
    if (this.initialMerchantKind !== null && !this.item.id) {
      this.item.merchantKind = this.initialMerchantKind;
      if (this.initialMerchantKind === 4) {
        this.item.title = 'مستودع مركزي';
        this.item.shortDescription = 'مستودع مركزي لتخزين وتجهيز المنتجات';
      }
    }
    this.loadForm();
    this.loadingUsers = true;
    this.subs.sink = this.userService
      .getMerchantUsers()
      .pipe(
        catchError(() => of([])),
        finalize(() => {
          this.loadingUsers = false;
          this.cdk.detectChanges();
        })
      )
      .subscribe((users) => {
        this.merchantUsers = users || [];
        this.cdk.detectChanges();
      });
  }

  loadForm() {
    const desc = (this.item.shortDescription || '').toLowerCase();
    const title = (this.item.title || '').toLowerCase();
    const isMarket = desc.includes('ماركت') ||
                     desc.includes('سوبرماركت') ||
                     desc.includes('سوبر ماركت') ||
                     desc.includes('أسواق') ||
                     desc.includes('بقالة') ||
                     desc.includes('تموينات') ||
                     desc.includes('مول') ||
                     desc.includes('market') ||
                     desc.includes('mart') ||
                     desc.includes('mall') ||
                     desc.includes('grocery') ||
                     desc.includes('hyper') ||
                     desc.includes('هايبر') ||
                     title.includes('ماركت') ||
                     title.includes('سوبرماركت') ||
                     title.includes('سوبر ماركت') ||
                     title.includes('هايبر') ||
                     title.includes('أسواق') ||
                     title.includes('بقالة') ||
                     title.includes('تموينات') ||
                     title.includes('مول') ||
                     title.includes('market') ||
                     title.includes('mart') ||
                     title.includes('mall') ||
                     title.includes('grocery');

    this.formGroup = this.fb.group({
      id: [this.item?.id],
      merchantKind: [this.item.merchantKind ?? (isMarket ? 1 : 0), [Validators.required]],
      title: [this.item.title, [Validators.required]],
      shortDescription: [this.item.shortDescription || '', [Validators.required]],
      description: [this.item.description],

      ibaN1Title: [this.item.ibaN1Title],
      ibaN1: [this.item.ibaN1],
      
      phone1: [this.item.phone1 || '', [Validators.required, Validators.minLength(8)]],
      phone2: [this.item.phone2 || '', [Validators.minLength(8)]],
      address: [this.item.address || ''],

      shippingCoverageInMeters: [this.item.shippingCoverageInMeters ?? 1000, [Validators.required]],
      lat: [this.item.lat ?? 34.7324, [Validators.required]],
      lng: [this.item.lng ?? 36.7137, [Validators.required]],
      profitOutOfMerchantPricePercent: [this.item.profitOutOfMerchantPricePercent ?? 0, [Validators.required, Validators.min(0)]],    
      deliveryTime: [this.item.deliveryTime || '20-30 دقيقة'],
      deliveryFee: [this.item.deliveryFee !== undefined && this.item.deliveryFee !== null ? this.item.deliveryFee : 50, [Validators.required, Validators.min(0)]],
      minOrderAmount: [this.item.minOrderAmount !== undefined && this.item.minOrderAmount !== null ? this.item.minOrderAmount : 150, [Validators.required, Validators.min(0)]],
      workingHours: [this.item.workingHours || 'حتى 3 ص'],
      active: [this.item.active ?? true],
      ownerName: [this.item.ownerName || this.item.owner || ''],
      owner: [this.item.ownerName || this.item.owner || ''],
      ownerId: [this.item.ownerId && this.item.ownerId !== '-' ? this.item.ownerId : null, [Validators.required]],
      photo: [this.item.photo || '']
    });

    ['phone1', 'phone2'].forEach((phoneControlName) => {
      const phoneControl = this.formGroup.get(phoneControlName);
      if (!phoneControl) return;
      this.subs.sink = phoneControl.valueChanges.subscribe(() => {
        if (!phoneControl.errors?.duplicatePhone) return;
        const errors = { ...phoneControl.errors };
        delete errors.duplicatePhone;
        phoneControl.setErrors(Object.keys(errors).length ? errors : null);
      });
    });

    this.subs.sink = this.formGroup.get('merchantKind')?.valueChanges.subscribe((type) => {
      const currentDesc = (this.formGroup.get('shortDescription')?.value || '').toString().trim();
      if (type === 1) {
        const hasKeyword = currentDesc.includes('ماركت') ||
                           currentDesc.includes('سوبرماركت') ||
                           currentDesc.includes('سوبر ماركت') ||
                           currentDesc.toLowerCase().includes('market');
        if (!hasKeyword) {
          this.formGroup.patchValue({
            shortDescription: currentDesc ? `سوبرماركت • ${currentDesc}` : 'سوبرماركت ومواد غذائية',
          });
        }
      } else if (type === 0) {
        const cleaned = currentDesc
          .replace(/سوبرماركت\s*•?\s*/g, '')
          .replace(/سوبر ماركت\s*•?\s*/g, '')
          .replace(/ماركت\s*•?\s*/g, '')
          .replace(/market\s*•?\s*/gi, '')
          .trim();
        this.formGroup.patchValue({
          shortDescription: cleaned || 'مطعم ومأكولات متنوعة',
        });
      } else if (type === 2) {
        const defaults = ['متجر متنوع', 'مطعم ومأكولات متنوعة', 'سوبرماركت ومواد غذائية'];
        if (!currentDesc || defaults.includes(currentDesc)) {
          this.formGroup.patchValue({ shortDescription: 'صيدلية ومنتجات صحية' });
        }
      } else if (type === 3 && !currentDesc) {
        this.formGroup.patchValue({ shortDescription: 'متجر متنوع' });
      } else if (type === 4 && !currentDesc) {
        this.formGroup.patchValue({ shortDescription: 'مستودع مركزي لتخزين وتجهيز المنتجات' });
      }
      this.cdk.detectChanges();
    });

    this.center = {
      lat: this.item.lat,
      lng: this.item.lng,
    };

    this.marker = {
      position: {
        lat: this.item.lat,
        lng: this.item.lng,
      },
      options: { animation: (window as any).google?.maps?.Animation?.DROP, draggable: true },
    };

    this.cdk.detectChanges();
  }

  onFileUploaded(filesIds: string[], key: string) {
    this.formGroup.patchValue({
      [key]: filesIds.join(",")
    });
    this.cdk.detectChanges();
  }

  onFileDelete(key: string) {
    this.formGroup.patchValue({
      [key]: '',
    });
    this.cdk.detectChanges();
  }

  save() {
    if (this.isSaving) return;
    if (this.formGroup.invalid) { this.formGroup.markAllAsTouched(); return; }
    if (!String(this.formGroup.get('title')?.value || '').trim()) {
      this.formGroup.get('title')?.setErrors({ required: true }); return;
    }
    const formValues = { ...this.formGroup.value };
    const merchantKind = Number(formValues.merchantKind);
    formValues.merchantKind = merchantKind;

    let desc = (formValues.shortDescription || '').toString().trim();
    if (merchantKind === 1) {
      const hasKeyword = desc.includes('ماركت') ||
                         desc.includes('سوبرماركت') ||
                         desc.includes('سوبر ماركت') ||
                         desc.includes('أسواق') ||
                         desc.includes('بقالة') ||
                         desc.includes('تموينات') ||
                         desc.toLowerCase().includes('market');
      if (!hasKeyword) {
        desc = desc ? `سوبرماركت • ${desc}` : 'سوبرماركت ومواد غذائية';
      }
    } else if (merchantKind === 0) {
      desc = desc
        .replace(/سوبرماركت\s*•?\s*/g, '')
        .replace(/سوبر ماركت\s*•?\s*/g, '')
        .replace(/ماركت\s*•?\s*/g, '')
        .replace(/market\s*•?\s*/gi, '')
        .replace(/بقالة\s*•?\s*/g, '')
        .trim();
      if (!desc) {
        desc = 'مطعم ومأكولات متنوعة';
      }
    } else if (merchantKind === 2 && !desc) {
      desc = 'صيدلية ومنتجات صحية';
    } else if (merchantKind === 3 && !desc) {
      desc = 'متجر متنوع';
    } else if (merchantKind === 4 && !desc) {
      desc = 'مستودع مركزي لتخزين وتجهيز المنتجات';
    }
    formValues.shortDescription = desc;

    const selectedOwner = this.merchantUsers.find((u) => u.id === formValues.ownerId);
    // The merchant display name can intentionally differ from the linked login account name.
    // Preserve an administrator's explicit edit; use the account name only as a fallback.
    const ownerName = (this.formGroup.get('ownerName')?.value || selectedOwner?.fullName || '').toString().trim();
    formValues.ownerName = ownerName;
    formValues.owner = ownerName;

    const isGuid = (val: any) =>
      typeof val === 'string' &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(val);
    if (!isGuid(formValues.ownerId) || !this.merchantUsers.some(u => u.id === formValues.ownerId && u.isActive)) {
      this.formGroup.get('ownerId')?.setErrors({ invalidAccount: true });
      this.toasterService.error('اختر حساب تاجر نشطاً مرتبطاً بالمتجر.');
      return;
    }

    this.isSaving = true;
    this.checkPhoneUniqueness(formValues);
  }

  private normalizePhone(value: unknown): string {
    const digits = String(value ?? '')
      .trim()
      .replace(/[٠-٩]/g, (digit: string) => String(digit.charCodeAt(0) - '٠'.charCodeAt(0)))
      .replace(/[۰-۹]/g, (digit: string) => String(digit.charCodeAt(0) - '۰'.charCodeAt(0)))
      .replace(/\D/g, '');

    if (digits.startsWith('00963')) return `0${digits.substring(5)}`;
    if (digits.startsWith('963')) return `0${digits.substring(3)}`;
    if (digits.length === 9 && digits.startsWith('9')) return `0${digits}`;
    return digits;
  }

  private checkPhoneUniqueness(formValues: Merchant): void {
    const phone1 = this.normalizePhone(formValues.phone1);
    const phone2 = this.normalizePhone(formValues.phone2);
    const phoneControls = [this.formGroup.get('phone1'), this.formGroup.get('phone2')];

    phoneControls.forEach((control) => {
      if (!control?.errors?.duplicatePhone) return;
      const errors = { ...control.errors };
      delete errors.duplicatePhone;
      control.setErrors(Object.keys(errors).length ? errors : null);
    });

    this.subs.sink = this.service
      .getAllMerchants()
      .pipe(catchError(() => of(null)))
      .subscribe((merchants) => {
        if (merchants === null) {
          this.isSaving = false;
          this.toasterService.error('تعذر فحص أرقام المتاجر. أعد المحاولة.');
          return;
        }
        const merchantId = Number(formValues.id || this.item?.id || 0);
        const duplicate = (merchants || []).find((merchant) => {
          if (merchant.id === merchantId) return false;
          const existingPhones = [
            this.normalizePhone(merchant.phone1),
            this.normalizePhone(merchant.phone2),
          ];
          return [phone1, phone2].filter(Boolean).some((phone) => existingPhones.includes(phone));
        });

        if (duplicate) {
          this.isSaving = false;
          const existingPhones = [
            this.normalizePhone(duplicate.phone1),
            this.normalizePhone(duplicate.phone2),
          ];
          this.markDuplicatePhone([
            phone1 && existingPhones.includes(phone1) ? phoneControls[0] : null,
            phone2 && existingPhones.includes(phone2) ? phoneControls[1] : null,
          ]);
          this.toasterService.error(`رقم الهاتف مستخدم مسبقاً للمتجر «${duplicate.title}».`);
          return;
        }

        if (this.item.id) {
          this.edit(formValues);
        } else {
          delete (formValues as any).id;
          this.create(formValues);
        }
      });
  }

  private markDuplicatePhone(controls: any[]): void {
    controls.forEach((control) => {
      if (!control) return;
      control.setErrors({ ...(control.errors || {}), duplicatePhone: true });
      control.markAsTouched();
    });
  }

  private handleSaveError(error: any): void {
    this.isSaving = false;
    const message = Array.isArray(error?.error?.errors) ? error.error.errors.join('، ') : typeof error?.error === 'string'
      ? error.error
      : error?.error?.message;
    this.toasterService.error(
      error?.status === 409
        ? (message || 'رقم الهاتف مستخدم مسبقاً لمتجر آخر.')
        : (error?.error?.errorDescription || message || 'تعذر حفظ بيانات المتجر، يرجى المحاولة مرة أخرى.')
    );
  }

  create(formValues: Merchant) {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('Merchant Added');
          this.modal.close({ ...formValues, id });
        }),
        catchError((error) => {
          this.handleSaveError(error);
          return of(null);
        })
      )
      .subscribe();
  }

  edit(formValues: Merchant) {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Merchant Updated');
          this.modal.close(formValues);
        }),
        catchError((error) => {
          this.handleSaveError(error);
          return of(null);
        })
      )
      .subscribe();
  }

  onCursorChange(event: google.maps.MapMouseEvent) {
    this.formGroup.patchValue({
      lat: event.latLng?.lat(),
      lng: event.latLng?.lng(),
    });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
