import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { Banner } from '../../models/banner.model';
import { BannersService } from '../../services/banners.service';

const EMPTY_BANNER: Banner = {
  id: '',
  title: '',
  description: '',
  order: 0,
  url: '',
  active: false,
  featuredImage: '',
  createdDate: '',
  bannerLocation: 0,
};

@Component({
  selector: 'app-edit-banner-modal',
  templateUrl: './edit-banner-modal.component.html',
})
export class EditBannerModalComponent implements OnInit {
  private subs = new SubSink();
  @Input() item: Banner;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;

  constructor(
    private bannersService: BannersService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.bannersService.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_BANNER;
    }
  }

  loadForm() {
    let placement = 'daily_offers';
    const rawUrl = this.item?.url || '';
    const rawDesc = this.item?.description || '';
    if (rawUrl.includes('section:dontmiss') || rawDesc.includes('dontmiss') || this.item?.bannerLocation === 1) {
      placement = 'dont_miss';
    } else if (rawUrl.includes('section:all')) {
      placement = 'all';
    }

    // Clean internal #section: tags from user input URL for clean display
    const cleanUrl = rawUrl.replace(/#section:[a-z_]+/g, '').trim();

    this.formGroup = this.fb.group({
      id: [this.item?.id],
      title: [this.item.title, [Validators.required]],
      description: [this.item.description, [Validators.required]],
      order: [this.item.order ?? 0, [Validators.required]],
      url: [cleanUrl],
      active: [this.item.active !== false],
      featuredImage: [this.item.featuredImage],
      bannerLocation: [this.item.bannerLocation ?? 0, [Validators.required]],
      sectionPlacement: [placement, [Validators.required]],
    });
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
    const formValues = { ...this.formGroup.value };
    const section = formValues.sectionPlacement;
    delete formValues.sectionPlacement;

    let url = (formValues.url || '').trim();
    url = url.replace(/#section:[a-z_]+/g, '').trim();

    if (section === 'dont_miss') {
      url = url ? `${url}#section:dontmiss` : '#section:dontmiss';
      formValues.bannerLocation = 1;
    } else if (section === 'all') {
      url = url ? `${url}#section:all` : '#section:all';
      formValues.bannerLocation = 0;
    } else {
      formValues.bannerLocation = 0;
    }
    formValues.url = url;

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: Banner) {
    this.subs.sink = this.bannersService
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Banner Added');          
          this.modal.close();
        })
      )
      .subscribe();
  }

  edit(formValues: Banner) {
    this.subs.sink = this.bannersService
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Banner Updated');
          this.modal.close();
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}

