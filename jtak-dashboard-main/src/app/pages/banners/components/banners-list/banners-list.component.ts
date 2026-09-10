import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { BannersService } from '../../services/banners.service';
import { EditBannerModalComponent } from '../edit-banner-modal/edit-banner-modal.component';
import { DeleteBannerModalComponent } from '../delete-banner-modal/delete-banner-modal.component';
import { Banner } from '../../models/banner.model';
import { forkJoin } from 'rxjs';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';

@Component({
  selector: 'app-banners-list',
  templateUrl: './banners-list.component.html',
  styles: [],
})
export class BannersListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;

  constructor(
    private fb: FormBuilder,
    public bannersService: BannersService,
    private modalService: NgbModal
  ) {
  }
  

  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.bannersService.patchState({ paginator });
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

    this.bannersService.patchState({ sorting });
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
    this.bannersService.patchState({ searchTerm });
  }

  // form actions
  create() {
    this.edit(null);
  }

  edit(item: Banner | null) {
    const modalRef = this.modalService.open(EditBannerModalComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.bannersService.fetchPost(),
      () => {}
    );
  }

  delete(id: string) {
    const modalRef = this.modalService.open(DeleteBannerModalComponent, {
      size: 'lg',
    });
    modalRef.componentInstance.id = id;
    modalRef.result.then(
      () => this.bannersService.fetchPost(),
      () => {}
    );
  }

  bulkDelete(items: Banner[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'banner' : 'banners';
    modalRef.componentInstance.action = () => forkJoin(selected.map((item) => this.bannersService.delete(item.id)));
    modalRef.result.then(() => { this.selection.clear(); this.bannersService.fetchPost(); }, () => {});
  }

  ngOnInit(): void {
    this.bannersService.setDefaults();
    this.searchForm();
    this.bannersService.fetchPost();
    this.subs.sink = this.bannersService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );
    this.sorting = this.bannersService.sorting;
    this.paginator = this.bannersService.paginator;
  }

  isDontMiss(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    const desc = (banner?.description || '').toLowerCase();
    return url.includes('section:dontmiss') || desc.includes('dontmiss') || banner?.bannerLocation === 1;
  }

  isAllSections(banner: Banner): boolean {
    const url = (banner?.url || '').toLowerCase();
    return url.includes('section:all');
  }

  isDailyOffers(banner: Banner): boolean {
    return !this.isDontMiss(banner) && !this.isAllSections(banner);
  }

  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
