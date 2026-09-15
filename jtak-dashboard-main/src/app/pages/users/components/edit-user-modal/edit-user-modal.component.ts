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
  formGroup: FormGroup;
  userRoles = Object.entries(AppUserRoleMap);

  constructor(
    private service: UsersService,
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    public filesService: FilesService,
    private toasterService: ToastrService
  ) {}

  getUserAvatar(): string | null {
    return this.formGroup?.get('profilePhoto')?.value || null;
  }

  getUserInitials(): string {
    const first = (this.formGroup?.get('firstName')?.value || '').trim()[0] || '';
    const last = (this.formGroup?.get('lastName')?.value || '').trim()[0] || '';
    return (first + last).toUpperCase() || 'U';
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
        [Validators.required, Validators.minLength(8), Validators.maxLength(15)],
      ],
      countryPhoneCode: [this.item.countryPhoneCode || '+963'],
      email: [this.item.email, [Validators.email]],
      password: ['', this.item?.id ? [] : [Validators.required, Validators.minLength(6)]],
      isActive: [this.item.isActive !== undefined ? this.item.isActive : true],
      profilePhoto: [this.item.profilePhoto],
      role: [this.item.role !== undefined ? this.item.role : 3],
      lang: [this.item.lang || 'ar']
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
