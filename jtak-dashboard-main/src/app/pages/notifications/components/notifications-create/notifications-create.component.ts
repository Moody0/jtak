import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { NotificationsService } from '../../services/notifications.service';
import { Notification } from '../../models/notification.model';


const EMPTY_NOTIFICATION: Notification = {
  id: 0,
  titleAr: '',
  titleEn: '',
  titleTr: '',
  title: '',
  textAr: '',
  textEn: '',
  textTr: '',
  text: '',
  notificationType: 0,
  image: '',
  url: ''
};

@Component({
  selector: 'app-notifications-create',
  templateUrl: './notifications-create.component.html',
  styles: [
  ]
})

export class NotificationsCreateComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: Notification;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;

  constructor(
    private notificationsService: NotificationsService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.notificationsService.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_NOTIFICATION;
    }
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      titleAr: [this.item.titleAr, [Validators.required]],
      //titleEn: [this.item.titleEn, [Validators.required]],
      //titleTr: [this.item.titleTr, [Validators.required]],
      textAr: [this.item.textAr, [Validators.required]],
      //textEn: [this.item.textEn, [Validators.required]],
      //textTr: [this.item.textTr, [Validators.required]],
      //notificationType: [this.item.notificationType, [Validators.required]],
      image: [this.item.image],
      //url: [this.item.url, [Validators.pattern]]
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
    const formValues = this.formGroup.value;
    console.log(formValues);
    delete formValues.id;
    this.create(formValues);
  }

  create(formValues: Notification) {
    this.subs.sink = this.notificationsService
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('Notification Added');          
          this.modal.close();
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
