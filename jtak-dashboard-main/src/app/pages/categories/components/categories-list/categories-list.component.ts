import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged, catchError } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { forkJoin, of } from 'rxjs';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
  IDeleteAction,
} from 'src/app/_metronic/shared/crud-table';
import { DeleteCategoryModalComponent } from '../delete-category-modal/delete-category-modal.component';
import { EditCategoryModalComponent } from '../edit-category-modal/edit-category-modal.component';
import { CategoriesService } from '../../services/categories.service';
import { Category } from '../../models/Category.model';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';

@Component({
  selector: 'app-categories-list',
  templateUrl: './categories-list.component.html',
  styleUrls: ['./categories-list.component.scss'],
})
export class CategoriesListComponent
  implements
    OnInit,
    OnDestroy,
    ISortView,
    IPaginatorView,
    ISearchView,
    IDeleteAction
{
  private subs = new SubSink();
  selection = new TableSelection<Category>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Parents and Hierarchy metadata
  parentCategories: Category[] = [];
  parentMap = new Map<number, string>();
  childrenCountMap = new Map<number, number>();

  // Filter state
  selectedLevel: 'all' | 'root' | 'sub' = 'all';
  selectedParentId: number | null = null;
  selectedStatus: 'all' | 'active' | 'inactive' = 'all';

  // System-wide KPIs
  kpiTotal = 0;
  kpiRoots = 0;
  kpiSubs = 0;
  kpiActive = 0;

  paginator: PaginatorState;
  sorting: SortState;

  constructor(
    private fb: UntypedFormBuilder,
    public service: CategoriesService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService
  ) {}

  ngOnInit(): void {
    this.service.setDefaults();
    this.service.setCategoryLevel('all');
    this.searchForm();
    this.loadHierarchyData();
    this.service.fetchPost();

    this.subs.sink = this.service.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.service.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      // KPI total is loaded from the full hierarchy, independently of filters.
    });

    this.sorting = this.service.sorting;
    this.paginator = this.service.paginator;
  }

  loadHierarchyData(): void {
    forkJoin({
      roots: this.service.getAll(true, true).pipe(catchError(() => of([]))),
      subs: this.service.getAll(false, true).pipe(catchError(() => of([]))),
    }).subscribe(({ roots, subs }) => {
      this.kpiTotal = roots.length + subs.length;
      this.parentMap.clear();
      this.parentCategories = roots;
      this.kpiRoots = roots.length;
      this.kpiSubs = subs.length;

      // Populate parent mapping
      roots.forEach((r) => this.parentMap.set(r.id, r.title));

      // Calculate subcategory counts per parent
      const counts = new Map<number, number>();
      subs.forEach((s) => {
        if (s.parentId) {
          counts.set(s.parentId, (counts.get(s.parentId) || 0) + 1);
        }
      });
      this.childrenCountMap = counts;

      const activeCount =
        roots.filter((r) => r.active).length +
        subs.filter((s) => s.active).length;
      this.kpiActive = activeCount;
    });
  }

  getParentTitle(parentId: number | null | undefined): string | null {
    if (!parentId) return null;
    return this.parentMap.get(parentId) || 'تصنيف رئيسي';
  }

  isRootCategory(category: Category): boolean {
    const parentId = category?.parentId;
    return parentId === null || parentId === undefined || Number(parentId) === 0;
  }

  getSubcategoriesCount(categoryId: number): number {
    return this.childrenCountMap.get(categoryId) || 0;
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

  filterByLevel(level: 'all' | 'root' | 'sub'): void {
    this.selectedLevel = level;
    this.selection.clear();
    this.service.setCategoryLevel(level);
    this.applyFilters();
  }

  filterByParent(parentId: number | null): void {
    this.selectedParentId = parentId;
    this.selection.clear();
    this.applyFilters();
  }

  filterByStatus(status: 'all' | 'active' | 'inactive'): void {
    this.selectedStatus = status;
    this.selection.clear();
    this.applyFilters();
  }

  clearSearch(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  resetFilters(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
    this.selectedLevel = 'all';
    this.selectedParentId = null;
    this.selectedStatus = 'all';
    this.selection.clear();
    this.service.setCategoryLevel('all');
    this.applyFilters();
  }

  getDisplayedItems(items: Category[]): Category[] {
    if (!items) return [];

    return items.filter((item) => {
      // Level filter
      const isRoot = this.isRootCategory(item);
      if (this.selectedLevel === 'root' && !isRoot) return false;
      if (this.selectedLevel === 'sub' && isRoot) return false;

      // Specific Parent filter
      if (this.selectedParentId !== null && item.parentId !== this.selectedParentId) {
        return false;
      }

      // Status filter
      if (this.selectedStatus === 'active' && !item.active) return false;
      if (this.selectedStatus === 'inactive' && item.active) return false;

      return true;
    });
  }

  private applyFilters(): void {
    const filter: any = {};
    if (this.selectedParentId !== null) filter.parentId = this.selectedParentId;
    if (this.selectedStatus !== 'all') filter.active = this.selectedStatus === 'active';
    this.service.patchState({ filter, paginator: Object.assign(this.service.paginator, { page: 0 }) });
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

  edit(item: Category | null): void {
    const modalRef = this.modalService.open(EditCategoryModalComponent, {
      size: 'xl',
      backdrop: 'static',
      keyboard: false,
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => {
        this.loadHierarchyData();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  changeStatus(category: Category): void {
    const wasActive = category.active;
    const updated = {
      ...category,
      active: !wasActive,
    };
    this.service.update(updated).subscribe({
      next: () => {
        this.toaster.success(
          wasActive ? 'تم تعطيل التصنيف بنجاح' : 'تم تفعيل التصنيف بنجاح'
        );
        this.service.fetchPost();
        this.loadHierarchyData();
      },
      error: () => {
        this.toaster.error('تعذر تحديث حالة التصنيف من الخادم، تمت استعادة الحالة الأصلية');
        this.service.fetchPost();
        this.loadHierarchyData();
      }
    });
  }

  delete(id: number): void {
    const modalRef = this.modalService.open(DeleteCategoryModalComponent);
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => {
        this.loadHierarchyData();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  bulkDelete(items: Category[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'category' : 'categories';
    modalRef.componentInstance.action = () =>
      forkJoin(selected.map((item) => this.service.delete(item.id)));
    modalRef.result.then(
      () => {
        this.selection.clear();
        this.loadHierarchyData();
        this.service.fetchPost();
      },
      () => {}
    );
  }

  refresh(): void {
    this.selection.clear();
    this.loadHierarchyData();
    this.service.fetchPost();
  }

  onImageError(event: any): void {
    event.target.src = './assets/media/svg/files/blank-image.svg';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
