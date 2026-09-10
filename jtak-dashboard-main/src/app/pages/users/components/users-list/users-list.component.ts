import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { forkJoin } from 'rxjs';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
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
@Component({
  selector: 'app-users-list',
  templateUrl: './users-list.component.html',
})
export class UsersListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;
  selecctedRoleId: number | undefined;
  userRoles:TagVal[]=[];
  constructor(
    private fb: FormBuilder,
    public service: UsersService,
    private modalService: NgbModal,
    private cdr:ChangeDetectorRef
  ) {
  }

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.service.patchState({ paginator });
  }

  sorting: SortState;
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

  updateSelectedRole() {
    if (this.selecctedRoleId)
    {
      this.service.fetchPost({ role: this.selecctedRoleId });
    }
      
    else
      this.service.fetchPost();
  }


  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string) {
    this.selection.clear();
    this.service.patchState({ searchTerm });
  }

  // form actions
  create() {
    this.edit(null);
  }

  edit(item: User | null) {
    const modalRef = this.modalService.open(EditUserModalComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  delete(id: string) {
    const modalRef = this.modalService.open(DeleteUserModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => this.service.fetchPost(),
      () => {}
    );
  }

  changeUserStatus(isActive: boolean, userId: string) {
    this.service.changeUserStatus(isActive, userId).subscribe(() => {
      this.service.fetchPost();
    });
  }

  bulkSetStatus(items: User[], enabled: boolean): void {
    const requests = this.selection.selectedItems(items)
      .filter((item) => item.isActive !== enabled)
      .map((item) => this.service.changeUserStatus(item.isActive, item.id));
    if (!requests.length) return;
    forkJoin(requests).subscribe(() => {
      this.selection.clear();
      this.service.fetchPost();
    });
  }

  ngOnInit(): void {
    this.service.setDefaults();
    this.searchForm();
    this.service.fetchPost();
    this.service.getRoles().subscribe((x) => 
    {
      console.log(x);
      console.log(this.userRoles);
      this.userRoles = x}
    );
    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
     this.cdr.detectChanges();
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
