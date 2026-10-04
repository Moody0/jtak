import { Component, OnDestroy, OnInit, ChangeDetectorRef } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { productReviewsService } from '../../services/product-reviews.service';
import { productReview } from '../../models/product-reviews.model';
import { FilesService } from 'src/app/modules/shared/services/files.service';

export interface RatingBadgeInfo {
  label: string;
  badgeClass: string;
  icon: string;
}

@Component({
  selector: 'app-product-reviews-list',
  templateUrl: './product-reviews-list.component.html',
  styleUrls: ['./product-reviews-list.component.scss'],
})
export class productReviewsListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView
{
  private subs = new SubSink();
  selection = new TableSelection<productReview>((item) => item.id);
  isLoading = false;
  totalRecords = 0;
  searchGroup: UntypedFormGroup;

  // Real Operational KPIs
  kpiTotal = 0;
  kpiAvgRating = 0;
  kpiFiveStarCount = 0;
  kpiFiveStarPct = 0;
  kpiCriticalCount = 0;
  kpiWithPhotoCount = 0;
  kpiWithTextCount = 0;

  // Rating Filter State
  selectedRatingFilter: 'all' | '5' | '4' | '3' | 'critical' | 'with_text' = 'all';

  // Modal State
  selectedReview: productReview | null = null;
  activePhotoUrl: string | null = null;

  paginator: PaginatorState;
  sorting: SortState;

  readonly ratingStars = [1, 2, 3, 4, 5];
  Number = Number;

  constructor(
    private fb: UntypedFormBuilder,
    public productReviewsService: productReviewsService,
    public filesService: FilesService,
    private modalService: NgbModal,
    private toaster: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.productReviewsService.setDefaults();
    this.sorting = this.productReviewsService.sorting;
    this.paginator = this.productReviewsService.paginator;
    this.searchForm();
    this.productReviewsService.fetchPost();

    this.subs.sink = this.productReviewsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.productReviewsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
    });

    this.subs.sink = this.productReviewsService.items$.subscribe(() => this.selection.clear());
    this.subs.sink = this.productReviewsService.summary$.subscribe(summary => {
      this.kpiTotal = summary?.total ?? 0;
      this.kpiAvgRating = summary?.averageRating ?? 0;
      this.kpiFiveStarCount = summary?.fiveStarCount ?? 0;
      this.kpiFiveStarPct = summary?.fiveStarPct ?? 0;
      this.kpiCriticalCount = summary?.criticalCount ?? 0;
      this.kpiWithTextCount = summary?.withTextCount ?? 0;
      this.cdr.detectChanges();
    });
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
    this.productReviewsService.patchState({ searchTerm });
  }

  clearSearch(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  filterByRating(filter: 'all' | '5' | '4' | '3' | 'critical' | 'with_text'): void {
    this.selectedRatingFilter = filter;
    this.productReviewsService.patchState({ filter: { ratingFilter: filter } });
    this.selection.clear();
  }

  getDisplayedItems(items: productReview[]): productReview[] {
    return items || [];
  }

  paginate(paginator: PaginatorState): void {
    this.selection.clear();
    this.productReviewsService.patchState({ paginator });
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
    this.productReviewsService.patchState({ sorting });
  }

  openReviewDetails(review: productReview, template: any): void {
    this.selectedReview = review;
    this.modalService.open(template, {
      size: 'lg',
      centered: true,
      windowClass: 'review-details-modal',
      backdrop: 'static',
      keyboard: true,
    });
  }

  openPhotoZoom(photoId: string, template: any, event?: Event): void {
    if (event) {
      event.stopPropagation();
    }
    this.activePhotoUrl = this.getPhotoUrl(photoId);
    this.modalService.open(template, {
      size: 'lg',
      centered: true,
      windowClass: 'review-photo-modal',
    });
  }

  getPhotoUrl(id: string): string {
    return this.filesService.getFile(id, 800, 800);
  }

  getThumbnailUrl(id: string): string {
    return this.filesService.getFile(id, 100, 100);
  }

  getRatingBadge(rate: any): RatingBadgeInfo {
    const val = Number(rate || 0);
    if (val >= 5) {
      return {
        label: 'ممتاز',
        badgeClass: 'rating-badge-excellent',
        icon: 'fas fa-smile',
      };
    } else if (val >= 4) {
      return {
        label: 'جيد جداً',
        badgeClass: 'rating-badge-good',
        icon: 'fas fa-smile-beam',
      };
    } else if (val >= 3) {
      return {
        label: 'متوسط',
        badgeClass: 'rating-badge-average',
        icon: 'fas fa-meh',
      };
    } else {
      return {
        label: 'ضعيف / شكوى',
        badgeClass: 'rating-badge-critical',
        icon: 'fas fa-frown',
      };
    }
  }

  cleanReviewerName(name: string): string {
    return String(name || '')
      .replace(/[\u200e\u200f\u061c]/gu, '')
      .replace(/^\s*ع[\u064b-\u065f\u0670\u0640]*م[\u064b-\u065f\u0670\u0640]*(?:\s+|$)/u, '')
      .trim();
  }

  async copyText(text: string | number, label: string = 'النص'): Promise<void> {
    if (text === null || text === undefined || text === '') return;
    try {
      await navigator.clipboard.writeText(String(text));
      this.toaster.info(`تم نسخ ${label} إلى الحافظة`);
    } catch {
      this.toaster.error('تعذر النسخ إلى الحافظة. يمكنك تحديد النص ونسخه يدوياً.');
    }
  }

  refresh(): void {
    this.selection.clear();
    this.productReviewsService.fetchPost();
  }

  exportSelection(items: productReview[]): void {
    this.selection.exportSelected(items, 'order-reviews');
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
