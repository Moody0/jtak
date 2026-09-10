import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { FormBuilder, FormGroup } from '@angular/forms';
import { PagesService } from '../../services/pages.service';
import { ActivatedRoute } from '@angular/router';
import { Page } from '../../models/pages.model';
import { Editor, Toolbar, Validators } from 'ngx-editor';
import { ToastrService } from 'ngx-toastr';
@Component({
  selector: 'app-page',
  templateUrl: './page.component.html',
})
export class PageComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  id: string;
  _pageData: Page;
  formGroup: FormGroup;
  editor: Editor;
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
    private fb: FormBuilder,
    private activatedRouter: ActivatedRoute,
    public service: PagesService,
    private cdk: ChangeDetectorRef
  ) {}

  loadForm() {
    this.formGroup = this.fb.group({
      title: [this._pageData.Title],
      body: [this._pageData.body, [Validators.required]],
    });
  }
  ngOnInit(): void {
    this.editor = new Editor();
    this.activatedRouter.params.subscribe((routeParams: any) => {
      this.id = routeParams.id;
      this.service.getPage(this.id).subscribe((res) => {
        this._pageData = res;
        this._pageData.Title = this.id;
        this.loadForm();
        this.cdk.detectChanges();
      });
    });
  }
  save() {
    this._pageData.body = this.formGroup.value;

    this.service.setPage(this.id, this.formGroup.value).subscribe((res) => {
      this.toasterService.success('تم الحفظ بنجاح');
    });
  }
  ngOnDestroy() {
    this.subs.unsubscribe();
    this.editor.destroy();
  }
}
