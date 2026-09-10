import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { tap } from 'rxjs/operators';
import { User } from '../../models/user.model';
import { UsersService } from '../../services/users.service';
import { AppUserRoleMap } from 'src/app/_metronic/config/settings';
import * as moment from 'moment';

const EMPTY_USER: User = {
  id: '',
  email: '',
  phoneNumber: '',
  firstName: '',
  lastName: '',
  fullName: '',
  isActive: false,
  profilePhoto: '',
  role: 3,
  lang: 'ar',
  countryPhoneCode: '',
};

@Component({
  selector: 'app-edit-user-modal',
  templateUrl: './edit-user-modal.component.html',
  styles: [],
})
export class EditUserModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() item: User;
  isLoading$: Observable<boolean>;
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);

  constructor(
    private service: UsersService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private toasterService: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
    this.loadItem();
    this.loadForm();
  }

  loadItem() {
    if (!this.item) {
      this.item = EMPTY_USER;
    }
  }

  loadForm() {
    this.formGroup = this.fb.group({
      id: [this.item?.id],
      firstName: [this.item.firstName, [Validators.required]],
      lastName: [this.item.lastName, [Validators.required]],
      phoneNumber: [
        this.item.countryPhoneCode?this.item.phoneNumber.replace(this.item.countryPhoneCode,''):this.item.phoneNumber,
        [Validators.required, Validators.minLength(8), Validators.maxLength(10)],
      ],
      email: [this.item.email, [Validators.email]],
      isActive: [this.item.isActive],
      profilePhoto: [this.item.profilePhoto],
      role: [this.item.role],
      lang: [this.item.lang]
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

    if (this.item.id) {
      this.edit(formValues);
    } else {
      delete formValues.id;
      this.create(formValues);
    }
  }

  create(formValues: User) {
    this.subs.sink = this.service
      .create(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('User Added');
          this.modal.close();
        })
      )
      .subscribe();
  }

  edit(formValues: User) {
    this.subs.sink = this.service
      .update(formValues)
      .pipe(
        tap(() => {
          this.toasterService.success('User Updated');
          this.modal.close();
        })
      )
      .subscribe();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
