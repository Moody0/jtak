import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Merchant } from '../../models/merchant.model';
import { MerchantsService } from '../../services/merchants.service';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import { UserModel } from 'src/app/modules/auth';
import { UsersService } from 'src/app/pages/users/services/users.service';
import { User } from 'src/app/pages/users/models/user.model';
import { HttpClient } from '@angular/common/http';

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
  ownerId: '-',
  owner: '',
  photo: ''
};

@Component({
  selector: 'app-edit-merchant-modal',
  templateUrl: './edit-merchant-modal.component.html',
  styles: [],
})
export class EditMerchantModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Merchant;
  merchantUsers: User[];
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

  constructor(
    private service: MerchantsService,
    private userService: UsersService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService,
    private cdk: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_Merchant;
    } else {
      //this.service.getItem(this.item.id).subscribe(merch => {
      //  this.item = merch as Merchant;
      //});
    }
    this.userService.getMerchantUsers()
                    .subscribe(users => this.merchantUsers = users);
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
      } else if (type === 2 && !currentDesc) {
        this.formGroup.patchValue({ shortDescription: 'صيدلية وأدوية وعناية صحية' });
      } else if (type === 3 && !currentDesc) {
        this.formGroup.patchValue({ shortDescription: 'متجر ومنتجات متنوعة' });
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
    } else if (merchantKind === 2 && !desc) {
      desc = 'صيدلية وأدوية وعناية صحية';
    } else if (merchantKind === 3 && !desc) {
      desc = 'متجر ومنتجات متنوعة';
    }
    formValues.shortDescription = desc;

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
