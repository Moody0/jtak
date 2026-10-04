import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError, map, finalize, mergeMap, tap } from 'rxjs/operators';
import { forkJoin, of, throwError } from 'rxjs';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { UsersService } from '../../services/users.service';
import { EditUserModalComponent } from '../edit-user-modal/edit-user-modal.component';
import { DeleteUserModalComponent } from '../delete-user-modal/delete-user-modal.component';
import { User } from '../../models/user.model';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { AppRoleName } from '../../enums/role.enum';

export interface RoleBadgeInfo {
  role: number;
  label: string;
  icon: string;
  badgeClass: string;
}

@Component({
  selector: 'app-users-list',
  templateUrl: './users-list.component.html',
  styleUrls: ['./users-list.component.scss'],
})
export class UsersListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  private destroyed=false;
  isMutating=false;
  selection = new TableSelection<User>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real System KPIs
  kpiTotal = 0;
  kpiActive = 0;
  kpiCustomers = 0;
  kpiStaff = 0;

  // Filter States
  selectedRoleId: number | 'all' = 'all';
  selectedStatus: 'all' | 'active' | 'disabled' = 'all';

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: UntypedFormBuilder,
    public service: UsersService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.sorting=this.service.sorting;this.paginator=this.service.paginator;
    this.searchForm();
    this.service.fetchPost();

    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.service.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
    });

    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
    this.subs.sink=this.service.summary$.subscribe(summary=>{this.kpiTotal=summary?.total ?? 0;this.kpiActive=summary?.active ?? 0;this.kpiCustomers=summary?.customers ?? 0;this.kpiStaff=summary?.staff ?? 0;this.cdr.detectChanges();});
  }

  searchForm(): void {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(400), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string): void {
    this.selection.clear();
    this.service.patchState({ searchTerm });
  }

  clearSearch(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  filterByRole(roleId: number | 'all'): void {
    this.selectedRoleId = roleId;
    this.selection.clear();
    this.applyFilters();
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
    this.applyFilters();
  }

  private applyFilters():void {
    const filter:any={};
    if(this.selectedRoleId!=='all') filter.role=this.selectedRoleId;
    if(this.selectedStatus!=='all') filter.isActive=this.selectedStatus==='active';
    this.service.patchState({filter});
  }

  getDisplayedItems(items:User[]):User[] {return items || [];}

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.service.patchState({ paginator });
  }

  sort(column: string): void {
    this.selection.clear();
    const sorting = this.sorting;
    const isActiveColumn = sorting.column === column;
    if (!isActiveColumn) {
      sorting.column = column;
      sorting.direction = 'ASC';
    } else {
      sorting.direction = sorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }
    this.service.patchState({ sorting });
  }

  create(): void {
    this.edit(null);
  }

  edit(item: User | null): void {
    const modalRef = this.modalService.open(EditUserModalComponent, {
      size: 'xl',
      windowClass: 'user-edit-modal',
      backdrop: 'static',
      keyboard: false,
      beforeDismiss:()=>!modalRef.componentInstance.isSaving,
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  delete(id: string): void {
    const modalRef = this.modalService.open(DeleteUserModalComponent, {
      centered: true,
      windowClass: 'user-delete-modal',
      backdrop:'static',
      beforeDismiss:()=>!modalRef.componentInstance.isSaving,
    });
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        this.refresh();
      },
      () => {}
    );
  }

  toggleUserStatus(user: User): void {
    if(this.isMutating) return;
    this.isMutating=true;
    this.subs.sink=this.service.changeUserStatus(user.isActive, user.id).pipe(finalize(()=>this.isMutating=false)).subscribe({next:() => {
      const stateText = !user.isActive
        ? 'تم تفعيل حساب المستخدم بنجاح'
        : 'تم تعطيل حساب المستخدم بنجاح';
      this.toaster.success(stateText);
      this.refresh();
    },error:err=>{this.toaster.error(err?.error?.errorDescription || err?.error?.message || 'تعذر تغيير حالة المستخدم. حدّث القائمة للتحقق.');this.refresh();}});
  }

  bulkSetStatus(items: User[], targetActive: boolean): void {
    if(this.isMutating) return;
    const requests = this.selection
      .selectedItems(items)
      .filter((item) => item.isActive !== targetActive)
      .map((item) => this.service.changeUserStatus(item.isActive, item.id).pipe(map(()=>true),catchError(()=>of(false))));

    if (!requests.length) return;

    this.isMutating=true;
    this.subs.sink=forkJoin(requests).pipe(finalize(()=>this.isMutating=false)).subscribe(results => {
      if(results.some(result=>!result))this.toaster.error(`تم تحديث ${results.filter(Boolean).length} من ${results.length} حساب. تعذر تحديث الباقي؛ راجع القائمة.`);
      else this.toaster.success(
        targetActive
          ? 'تم تفعيل الحسابات المحددة بنجاح'
          : 'تم تعطيل الحسابات المحددة بنجاح'
      );
      this.selection.clear();
      this.refresh();
    });
  }

  bulkDelete(items: User[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent,{backdrop:'static',beforeDismiss:()=>!modalRef.componentInstance.isLoading});
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = 'حساب';
    modalRef.componentInstance.actionLabel = 'أرشفة';
    modalRef.componentInstance.description = 'سيُوقف دخول الحسابات المحددة مع الاحتفاظ بالطلبات والسجلات المالية السابقة.';
    modalRef.componentInstance.action = () =>
      forkJoin(selected.map((item) => this.service.delete(item.id).pipe(map(()=>true),catchError(()=>of(false))))).pipe(
        tap(()=>this.refresh()),mergeMap(results=>results.every(Boolean) ? of(results) : throwError(()=>({error:{message:`تمت أرشفة ${results.filter(Boolean).length} من ${results.length} حساب. راجع القائمة للحسابات المتبقية.`}}))));
    modalRef.result.then(
      () => {
        this.selection.clear();
        this.refresh();
      },
      () => {}
    );
  }

  // Roles are authoritative in the API/database. Do not infer a role from a
  // user's name or email because that can make the table contradict the
  // actual AspNetUserRoles assignment.
  getUserRole(user: User): number {
    if (user.role !== undefined && user.role !== null) {
      const numericRole = Number(user.role);
      if (Number.isInteger(numericRole)) {
        return numericRole;
      }

      // Be tolerant of APIs returning enum names instead of their numeric value.
      const roleName = String(user.role).trim().toLowerCase();
      const roleByName: { [key: string]: AppRoleName } = {
        admin: AppRoleName.Admin,
        customer: AppRoleName.Customer,
        merchant: AppRoleName.Merchant,
        delivery: AppRoleName.Delivery,
      };
      if (roleByName[roleName] !== undefined) {
        return roleByName[roleName];
      }
    }

    return AppRoleName.Customer; // 1
  }

  getRoleBadgeInfo(user: User): RoleBadgeInfo {
    const role = this.getUserRole(user);
    switch (role) {
      case AppRoleName.Admin:
        return {
          role: 0,
          label: 'مدير النظام',
          icon: 'fas fa-user-shield',
          badgeClass: 'role-admin',
        };
      case AppRoleName.Merchant:
        return {
          role: 2,
          label: 'تاجر',
          icon: 'fas fa-store',
          badgeClass: 'role-merchant',
        };
      case AppRoleName.Delivery:
        return {
          role: 3,
          label: 'مندوب توصيل',
          icon: 'fas fa-motorcycle',
          badgeClass: 'role-delivery',
        };
      default:
        return {
          role: 1,
          label: 'عميل',
          icon: 'fas fa-user',
          badgeClass: 'role-customer',
        };
    }
  }

  getCaptainCompensationBadge(user: User): { label: string; badgeClass: string } | null {
    if (this.getUserRole(user) !== AppRoleName.Delivery) {
      return null;
    }
    const type = Number(user.captainCompensationType ?? 0);
    const rate = user.captainRate ?? 0;
    switch (type) {
      case 0:
        return { label: 'موظف براتب', badgeClass: 'type-salaried' };
      case 1:
        return { label: rate + ' ل.س / كم', badgeClass: 'type-km' };
      case 2:
        return { label: 'نسبة ' + rate + '%', badgeClass: 'type-percent' };
      default:
        return { label: 'موظف براتب', badgeClass: 'type-salaried' };
    }
  }

  hasRealName(user: User): boolean {
    const first = (user.firstName || '').trim();
    const last = (user.lastName || '').trim();
    const full = (user.fullName || '').trim();
    if (first && !first.startsWith('#')) return true;
    if (full && !full.startsWith('#')) return true;
    return false;
  }

  getUserDisplayName(user: User): string {
    const first = (user.firstName || '').trim();
    const last = (user.lastName || '').trim();
    if (first && !first.startsWith('#')) {
      return `${first} ${last}`.trim();
    }
    if (user.fullName && !user.fullName.startsWith('#')) {
      return user.fullName.trim();
    }
    if (user.phoneNumber) {
      return `عميل (${user.phoneNumber})`;
    }
    return `مستخدم #${user.id?.slice(0, 8)}`;
  }

  getUserInitials(user: User): string {
    const first = (user.firstName || user.fullName || '').trim()[0] || '';
    const last = (user.lastName || '').trim()[0] || '';
    const initials = (first + last).toUpperCase();
    return initials && !initials.includes('#') ? initials : 'U';
  }

  formatPhone(user: User): string {
    if (!user.phoneNumber) return '-';
    let phone = user.phoneNumber.trim();
    const code = (user.countryPhoneCode || '').trim();

    // Avoid duplicate prefix like "+963 +963912345677"
    if (code && phone.startsWith(code)) {
      return phone;
    }
    if (phone.startsWith('+')) {
      return phone;
    }
    if (code) {
      return `${code} ${phone}`;
    }
    return phone;
  }

  refresh(): void {
    if(this.destroyed) return;
    this.selection.clear();
    this.service.fetchPost();
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.destroyed=true;
    this.subs.unsubscribe();
  }
}
