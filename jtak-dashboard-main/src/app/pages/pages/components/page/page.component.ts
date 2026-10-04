import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { PagesService } from '../../services/pages.service';
import { ActivatedRoute } from '@angular/router';
import { Page } from '../../models/pages.model';
import { Editor, Toolbar, Validators } from 'ngx-editor';
import { ToastrService } from 'ngx-toastr';
import { Subscription } from 'rxjs';
import { TranslateService } from '@ngx-translate/core';
@Component({
  selector: 'app-page',
  templateUrl: './page.component.html',
  styleUrls: ['./page.component.scss'],
})
export class PageComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  private pageLoadSub?: Subscription;
  private copySub?: Subscription;
  private saveSub?: Subscription;
  private scopeVersion = 0;
  hasLoaded = false;
  loadError = false;
  isCopying = false;
  id: string;
  _pageData: Page | null = null;
  formGroup: UntypedFormGroup;
  editor: Editor;
  isLoadingPage = false;
  isSaving = false;
  selectedTermsApp = 'customer';
  readonly termsApps = [
    { key: 'customer', labelKey: 'PAGES.TERMS_CUSTOMER_APP' },
    { key: 'delivery', labelKey: 'PAGES.TERMS_DELIVERY_APP' },
    { key: 'warehouse', labelKey: 'PAGES.TERMS_WAREHOUSE_APP' },
  ];
  toolbar: Toolbar = [
    ['bold', 'italic'],
    ['underline', 'strike'],
    ['code', 'blockquote'],
    ['ordered_list', 'bullet_list'],
    [{ heading: ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'] }],
    ['link', 'image'],
    ['text_color', 'background_color'],
    ['align_left', 'align_center', 'align_right', 'align_justify'],
  ];

  constructor(
    public toasterService: ToastrService,
    private fb: UntypedFormBuilder,
    private activatedRouter: ActivatedRoute,
    public service: PagesService,
    private cdk: ChangeDetectorRef,
    private translate: TranslateService
  ) {}

  loadForm() {
    const values = { title: this._pageData?.Title || this.id, body: this._pageData?.body || '' };
    if (this.formGroup) this.formGroup.reset(values);
    else this.formGroup = this.fb.group({ title: [values.title], body: [values.body, [Validators.required]] });
    if (this.hasLoaded) this.formGroup.enable(); else this.formGroup.disable();
  }

  get isTermsPage(): boolean {
    return (this.id || '').toLowerCase() === 'termsandconditions';
  }

  get isPageBodyEmpty(): boolean {
    const body = String(this.formGroup?.get('body')?.value || '');
    return body
      .replace(/<[^>]*>/g, '')
      .replace(/&nbsp;|&#160;|\u00a0/gi, ' ')
      .trim().length === 0;
  }

  ngOnInit(): void {
    this.editor = new Editor();
    this.subs.sink = this.activatedRouter.params.subscribe((routeParams: any) => {
      this.id = routeParams.id;
      this.selectedTermsApp = 'customer';
      this.loadPage();
    });
  }

  selectTermsApp(app: string): void {
    if (this.selectedTermsApp === app || this.isSaving || this.isCopying || !this.termsApps.some(item => item.key === app)) return;
    this.selectedTermsApp = app;
    this.loadPage();
  }

  loadPage(): void {
    if (!this.id) return;
    this.scopeVersion++;
    this.copySub?.unsubscribe();
    this.isCopying = false;
    this.pageLoadSub?.unsubscribe();
    this.hasLoaded = false;
    this.loadError = false;
    this.isLoadingPage = true;
    this.pageLoadSub = this.service.getPage(
      this.id,
      this.isTermsPage ? this.selectedTermsApp : undefined
    ).subscribe({
      next: (res) => {
        this._pageData = res || ({} as Page);
        this._pageData.Title = this.id;
        this.hasLoaded = true;
        this.loadForm();
        this.isLoadingPage = false;
        this.cdk.detectChanges();
      },
      error: () => {
        this.loadError = true;
        this._pageData = null;
        this.loadForm();
        this.isLoadingPage = false;
        this.toasterService.error(this.translate.instant('PAGES.TERMS_LOAD_ERROR'));
        this.cdk.detectChanges();
      },
    });
  }

  copyCustomerTerms(): void {
    if (!this.isTermsPage || this.selectedTermsApp === 'customer' || this.isSaving || this.isLoadingPage || this.isCopying || !this.hasLoaded) return;
    this.isCopying = true;
    this.formGroup.disable();
    this.copySub = this.service.getPage(this.id, 'customer').subscribe({
      next: (page) => {
        this.isCopying = false;
        this.formGroup.enable();
        this.formGroup.markAsDirty();
        this.formGroup.patchValue({ body: page?.body || '' });
        this.toasterService.info(this.translate.instant('PAGES.TERMS_COPY_SUCCESS'));
      },
      error: () => { this.isCopying = false; this.formGroup.enable(); this.toasterService.error(this.translate.instant('PAGES.TERMS_COPY_ERROR')); },
    });
  }

  save() {
    if (!this.formGroup || this.formGroup.invalid || this.isSaving || this.isLoadingPage || this.isCopying || !this.hasLoaded || this.isPageBodyEmpty) {
      this.formGroup?.markAllAsTouched();
      return;
    }
    const page = {
      title: this.id,
      body: this.formGroup.value.body,
    };
    this.isSaving = true;
    this.formGroup.disable();
    const scope = this.scopeVersion;
    this.saveSub = this.service.setPage(
      this.id,
      page,
      this.isTermsPage ? this.selectedTermsApp : undefined
    ).subscribe({
      next: () => {
        this.isSaving = false;
        if (scope !== this.scopeVersion) return;
        this.formGroup.enable();
        this.formGroup.markAsPristine();
        if (this._pageData) this._pageData.body = page.body;
        this.toasterService.success('تم الحفظ بنجاح');
        this.isSaving = false;
      },
      error: () => {
        this.isSaving = false;
        if (scope !== this.scopeVersion) return;
        this.formGroup.enable();
        this.toasterService.error(this.translate.instant('PAGES.TERMS_SAVE_ERROR'));
        this.isSaving = false;
      },
    });
  }
  ngOnDestroy() {
    this.subs.unsubscribe();
    this.pageLoadSub?.unsubscribe();
    this.copySub?.unsubscribe();
    this.saveSub?.unsubscribe();
    this.editor.destroy();
  }
}
