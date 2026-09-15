import { ChangeDetectorRef, Component, Input, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { Subject } from 'rxjs';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { SearchProductCandidate } from '../../models/popular-product.model';
import { PopularProductsService } from '../../services/popular-products.service';

@Component({
  selector: 'app-add-popular-product-modal',
  templateUrl: './add-popular-product-modal.component.html',
  styleUrls: ['./add-popular-product-modal.component.scss'],
})
export class AddPopularProductModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  private searchSubject = new Subject<string>();

  @Input() existingIds: number[] = [];
  @Input() nextOrder = 1;

  formGroup: FormGroup;
  candidates: SearchProductCandidate[] = [];
  selectedProduct: SearchProductCandidate | null = null;
  isSearching = false;
  isSubmitting = false;

  constructor(
    public modal: NgbActiveModal,
    private fb: FormBuilder,
    private popularService: PopularProductsService,
    public filesService: FilesService,
    private toastr: ToastrService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.formGroup = this.fb.group({
      searchTerm: [''],
      productId: [null, [Validators.required]],
      order: [this.nextOrder, [Validators.required, Validators.min(1)]],
      customBadge: ['الأكثر طلباً'],
      customTitle: [''],
    });

    this.subs.sink = this.searchSubject
      .pipe(debounceTime(350), distinctUntilChanged())
      .subscribe((term) => {
        this.performSearch(term);
      });

    // Initial search with top candidates
    this.performSearch('');
  }

  onSearchChange(term: string): void {
    this.searchSubject.next(term);
  }

  performSearch(query: string): void {
    this.isSearching = true;
    this.subs.sink = this.popularService.searchProducts(query, undefined, 40).subscribe({
      next: (res) => {
        this.isSearching = false;
        this.candidates = res || [];
        this.cdr.detectChanges();
      },
      error: () => {
        this.isSearching = false;
        this.toastr.error('تعذر البحث عن المنتجات');
        this.cdr.detectChanges();
      },
    });
  }

  selectProduct(prod: SearchProductCandidate): void {
    this.selectedProduct = prod;
    this.formGroup.patchValue({
      productId: prod.id,
      customTitle: prod.title,
    });
  }

  submit(): void {
    if (this.formGroup.invalid || !this.selectedProduct) {
      this.toastr.warning('يرجى اختيار منتج أولاً');
      return;
    }

    this.isSubmitting = true;
    const val = this.formGroup.value;

    this.popularService
      .addItem({
        productId: val.productId,
        order: val.order || this.nextOrder,
        active: true,
        customBadge: val.customBadge || 'الأكثر طلباً',
        customTitle: val.customTitle || this.selectedProduct.title,
      })
      .subscribe({
        next: () => {
          this.isSubmitting = false;
          this.toastr.success('تمت إضافة المنتج إلى قائمة الأكثر طلباً');
          this.modal.close(true);
        },
        error: () => {
          this.isSubmitting = false;
          this.toastr.error('تعذر إضافة المنتج');
          this.cdr.detectChanges();
        },
      });
  }

  onImageError(event: any): void {
    event.target.style.display = 'none';
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
