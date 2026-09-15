import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
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
  lat: 37.064258,
  lng: 37.378656,
  active: false,
  merchantKind: 0,
  deliveryTime: '20-30 دقيقة',
  deliveryFee: 5000,
  minOrderAmount: 15000,
  workingHours: 'حتى 3 ص',
  ownerId: '-',
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
  merchantUsers: User[] = [];
  loadingUsers = false;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);
  zoom = 10;
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
  deliveryFeePresets: number[] = [0, 3000, 5000, 7000, 10000];
  minOrderPresets: number[] = [10000, 15000, 20000, 25000, 30000, 50000];
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
    private fb: FormBuilder,
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
    this.formGroup.get('merchantKind')?.setValue(val);
  }

  getStorePhoto(): string | null {
    return this.formGroup?.get('photo')?.value || null;
  }

  getKindInfo(): { label: string; icon: string; emoji: string } {
    const kind = Number(this.formGroup?.get('merchantKind')?.value ?? 0);
    switch (kind) {
      case 1:
      case 3:
        return { label: 'سوبرماركت / بقالية', icon: 'fas fa-shopping-basket', emoji: '🛒' };
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
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_Merchant;
    }
    this.loadingUsers = true;
    this.userService
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
        if (
          this.item.ownerId &&
          this.item.ownerId !== '-' &&
          !this.merchantUsers.some((u) => u.id === this.item.ownerId)
        ) {
          this.merchantUsers.unshift({
            id: this.item.ownerId,
            fullName: this.item.owner || 'مالك المتجر الحالي',
            phoneNumber: this.item.phone1 || '',
            email: '',
            firstName: '',
            lastName: '',
            profilePhoto: '',
            isActive: true,
            role: 'Merchant' as any,
            lang: 'ar',
            countryPhoneCode: '+963',
          });
        }
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
      lat: [this.item.lat ?? 37.064258, [Validators.required]],
      lng: [this.item.lng ?? 37.378656, [Validators.required]],
      profitOutOfMerchantPricePercent: [this.item.profitOutOfMerchantPricePercent ?? 0, [Validators.required]],    
      deliveryTime: [this.item.deliveryTime || '20-30 دقيقة'],
      deliveryFee: [this.item.deliveryFee !== undefined && this.item.deliveryFee !== null ? this.item.deliveryFee : 5000, [Validators.required, Validators.min(0)]],
      minOrderAmount: [this.item.minOrderAmount !== undefined && this.item.minOrderAmount !== null ? this.item.minOrderAmount : 15000, [Validators.required, Validators.min(0)]],
      workingHours: [this.item.workingHours || 'حتى 3 ص'],
      active: [this.item.active ?? true],
      ownerId: [this.item.ownerId],
      photo: [this.item.photo || '']
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
      options: { animation: google.maps.Animation.DROP, draggable: true },
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
    }
    formValues.shortDescription = desc;

    // Synchronize owner display title
    const selectedUser = this.merchantUsers.find((u) => u.id === formValues.ownerId);
    if (selectedUser) {
      formValues.owner = selectedUser.fullName;
    } else if (!formValues.ownerId || formValues.ownerId === '-') {
      formValues.owner = '';
    }

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Merchant) {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap((id) => {
          this.toasterService.success('Merchant Added');
          this.modal.close({ ...formValues, id });
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
