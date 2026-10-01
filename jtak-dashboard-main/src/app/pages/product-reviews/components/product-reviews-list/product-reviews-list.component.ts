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
  selectedRatingFilter: 'all' | '5' | '4' | '3' | 'critical' | 'with_text' | 'with_photo' = 'all';

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
    this.searchForm();
    this.productReviewsService.fetchPost();

    this.subs.sink = this.productReviewsService.isLoading$.subscribe(
      (res) => (this.isLoading = res)
    );

    this.subs.sink = this.productReviewsService.totalRecords$.subscribe((total) => {
      this.totalRecords = total || 0;
      if (!this.kpiTotal && this.totalRecords) {
        this.kpiTotal = this.totalRecords;
      }
    });

    this.subs.sink = this.productReviewsService.items$.subscribe((items) => {
      this.calculateKpis(items || []);
    });

    this.sorting = this.productReviewsService.sorting;
    this.paginator = this.productReviewsService.paginator;
  }

  calculateKpis(items: productReview[]): void {
    if (!items || !items.length) return;
    this.kpiTotal = this.totalRecords > items.length ? this.totalRecords : items.length;

    let sumRating = 0;
    let fiveStar = 0;
    let critical = 0;
    let withPhoto = 0;
    let withText = 0;

    for (const r of items) {
      const rate = Number(r.rate || 0);
      sumRating += rate;
      if (rate >= 5) fiveStar++;
      if (rate <= 2 && rate > 0) critical++;
      if (r.imageReview && String(r.imageReview).trim()) withPhoto++;
      if (r.textReview && String(r.textReview).trim()) withText++;
    }

    this.kpiAvgRating = Math.round((sumRating / items.length) * 10) / 10;
    this.kpiFiveStarCount = fiveStar;
    this.kpiFiveStarPct = Math.round((fiveStar / items.length) * 100);
    this.kpiCriticalCount = critical;
    this.kpiWithPhotoCount = withPhoto;
    this.kpiWithTextCount = withText;
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
    this.productReviewsService.patchState({ searchTerm });
  }

  clearSearch(): void {
    this.searchGroup.get('searchTerm')?.setValue('');
  }

  filterByRating(filter: 'all' | '5' | '4' | '3' | 'critical' | 'with_text' | 'with_photo'): void {
    this.selectedRatingFilter = filter;
    this.selection.clear();
  }

  getDisplayedItems(items: productReview[]): productReview[] {
    if (!items) return [];

    return items.filter((item) => {
      const rate = Number(item.rate || 0);

      switch (this.selectedRatingFilter) {
        case '5':
          return rate >= 5;
        case '4':
          return rate >= 4 && rate < 5;
        case '3':
          return rate >= 3 && rate < 4;
        case 'critical':
          return rate <= 2;
        case 'with_text':
          return Boolean(item.textReview && String(item.textReview).trim());
        case 'with_photo':
          return Boolean(item.imageReview && String(item.imageReview).trim());
        case 'all':
        default:
          return true;
      }
    });
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

  getReviewerInitials(name: string): string {
    const trimmed = (name || '').trim();
    if (!trimmed) return 'U';
    const parts = trimmed.split(' ').filter(Boolean);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed.slice(0, 2).toUpperCase();
  }

  copyText(text: string, label: string = 'النص'): void {
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
      this.toaster.info(`تم نسخ ${label} إلى الحافظة`);
    });
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
