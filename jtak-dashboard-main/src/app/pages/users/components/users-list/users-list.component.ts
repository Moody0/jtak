import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError } from 'rxjs/operators';
import { forkJoin, of } from 'rxjs';
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
import { TagVal } from '../../models/TagVal-dto.model';
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
  selection = new TableSelection<User>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: FormGroup;

  // Real System KPIs
  kpiTotal = 0;
  kpiActive = 0;
  kpiCustomers = 0;
  kpiStaff = 0;

  // Filter States
  selectedRoleId: number | 'all' = 'all';
  selectedStatus: 'all' | 'active' | 'disabled' = 'all';
  userRoles: TagVal[] = [];

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: FormBuilder,
    public service: UsersService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.searchForm();
    this.loadKpis();
    this.service.fetchPost();

    this.service.getRoles().subscribe((roles) => {
      this.userRoles = roles || [];
      this.cdr.detectChanges();
    });

    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.service.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiTotal) {
        this.kpiTotal = this.totalRecords;
      }
    });

    // Reactive KPI calculation from loaded items to guarantee no zero values
    this.subs.sink = this.service.items$.subscribe((items) => {
      if (items && items.length) {
        this.calculateKpis(items);
      }
    });

    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
  }

  loadKpis(): void {
    this.service
      .getAllUsers()
      .pipe(catchError(() => of([])))
      .subscribe((users) => {
        if (users && users.length) {
          this.calculateKpis(users);
        }
      });
  }

  calculateKpis(users: User[]): void {
    if (!users || !users.length) return;
    this.kpiTotal = this.totalRecords > users.length ? this.totalRecords : users.length;
    this.kpiActive = users.filter((u) => u.isActive).length;
    this.kpiCustomers = users.filter(
      (u) => this.getUserRole(u) === AppRoleName.Customer
    ).length;
    this.kpiStaff = users.filter(
      (u) => this.getUserRole(u) !== AppRoleName.Customer
    ).length;
    this.cdr.detectChanges();
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

  filterByRole(roleId: number | 'all'): void {
    this.selectedRoleId = roleId;
    this.selection.clear();
    if (roleId !== 'all') {
      this.service.fetchPost({ role: roleId });
    } else {
      this.service.fetchPost();
    }
  }

  filterByStatus(status: 'all' | 'active' | 'disabled'): void {
    this.selectedStatus = status;
    this.selection.clear();
  }

  getDisplayedItems(items: User[]): User[] {
    if (!items) return [];

    return items.filter((user) => {
      // Role filter (client-side backup for mixed sets)
      if (this.selectedRoleId !== 'all') {
        const userRole = this.getUserRole(user);
        if (userRole !== this.selectedRoleId) {
          return false;
        }
      }

      // Status filter
      if (this.selectedStatus === 'active' && !user.isActive) return false;
      if (this.selectedStatus === 'disabled' && user.isActive) return false;

      return true;
    });
  }

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
      backdrop: 'static',
      keyboard: false,
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => {
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  delete(id: string): void {
    const modalRef = this.modalService.open(DeleteUserModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  toggleUserStatus(user: User): void {
    this.service.changeUserStatus(user.isActive, user.id).subscribe(() => {
      const stateText = !user.isActive
        ? 'تم تفعيل حساب المستخدم بنجاح'
        : 'تم تعطيل حساب المستخدم بنجاح';
      this.toaster.success(stateText);
      this.loadKpis();
      this.service.fetchPost();
    });
  }

  bulkSetStatus(items: User[], targetActive: boolean): void {
    const requests = this.selection
      .selectedItems(items)
      .filter((item) => item.isActive !== targetActive)
      .map((item) => this.service.changeUserStatus(item.isActive, item.id));

    if (!requests.length) return;

    forkJoin(requests).subscribe(() => {
      this.toaster.success(
        targetActive
          ? 'تم تفعيل الحسابات المحددة بنجاح'
          : 'تم تعطيل الحسابات المحددة بنجاح'
      );
      this.selection.clear();
      this.loadKpis();
      this.service.fetchPost();
    });
  }

  bulkDelete(items: User[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'user' : 'users';
    modalRef.componentInstance.action = () =>
      forkJoin(selected.map((item) => this.service.delete(item.id)));
    modalRef.result.then(
      () => {
        this.selection.clear();
        this.loadKpis();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  // Smart Role Resolver to handle drivers and unassigned roles
  getUserRole(user: User): number {
    const email = (user.email || '').toLowerCase();
    const name = (user.firstName || user.fullName || '').toLowerCase();

    if (
      email.startsWith('driver_') ||
      name.includes('driver') ||
      name.includes('سائق') ||
      name.includes('مندوب') ||
      name.includes('كابتن')
    ) {
      return AppRoleName.Delivery; // 3
    }

    if (user.role !== undefined && user.role !== null) {
      return Number(user.role);
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
    this.selection.clear();
    this.loadKpis();
    this.service.fetchPost();
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
