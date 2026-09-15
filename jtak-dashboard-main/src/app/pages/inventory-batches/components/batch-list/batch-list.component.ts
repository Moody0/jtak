import { Component, OnInit, OnDestroy, TemplateRef, ViewChild } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Subject, Subscription } from 'rxjs';
import { debounceTime, distinctUntilChanged, switchMap } from 'rxjs/operators';
import {
  ProductBatch,
  CreateProductBatchDto,
  StockAdjustmentDto,
  BatchStatus,
  InventoryBatchKpi,
  BatchProductLookup,
  BatchMerchantLookup,
} from '../../models/product-batch.model';
import { InventoryBatchService } from '../../services/inventory-batch.service';

@Component({
  selector: 'app-batch-list',
  templateUrl: './batch-list.component.html',
  styleUrls: ['./batch-list.component.scss'],
})
export class BatchListComponent implements OnInit, OnDestroy {
  batches: ProductBatch[] = [];
  filteredBatches: ProductBatch[] = [];
  pagedBatches: ProductBatch[] = [];
  alerts: ProductBatch[] = [];
  kpis: InventoryBatchKpi | null = null;
  merchantsList: BatchMerchantLookup[] = [];

  productSearchResults: BatchProductLookup[] = [];
  isSearchingProducts = false;
  productSearch$ = new Subject<string>();

  isLoading = false;
  isSubmitting = false;
  hasError = false;
  errorMessage = '';

  searchQuery = '';
  selectedStatus: string = 'all';
  selectedMerchantFilter: string = 'all';
  selectedSort: string = 'fefo';

  // Pagination
  page = 1;
  pageSize = 10;
  totalItems = 0;
  readonly Math = Math;

  createForm!: FormGroup;
  adjustForm!: FormGroup;
  selectedBatch: ProductBatch | null = null;
  selectedProductDetails: BatchProductLookup | null = null;
  printBatch: ProductBatch | null = null;

  @ViewChild('createModal') createModal!: TemplateRef<any>;
  @ViewChild('adjustModal') adjustModal!: TemplateRef<any>;
  @ViewChild('printModal') printModal!: TemplateRef<any>;

  private subs = new Subscription();

  constructor(
    private batchService: InventoryBatchService,
    private modalService: NgbModal,
    private fb: FormBuilder
  ) {}

  ngOnInit(): void {
    this.initForms();
    this.setupProductSearch();
    this.loadData();
    this.loadMerchants();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  initForms(): void {
    this.createForm = this.fb.group({
      productId: [null, [Validators.required, Validators.min(1)]],
      merchantId: [null, [Validators.required, Validators.min(1)]],
      batchNumber: ['', Validators.required],
      lotNumber: [''],
      barcode: ['', Validators.required],
      sku: [''],
      locationBin: ['', Validators.required],
      manufactureDate: [null],
      expirationDate: ['', Validators.required],
      initialQuantity: [1, [Validators.required, Validators.min(1)]],
      costPrice: [0, [Validators.required, Validators.min(0)]],
      sellingPrice: [null],
      notes: [''],
    });

    this.adjustForm = this.fb.group({
      adjustmentType: ['deduct', Validators.required], // 'add' | 'deduct'
      quantity: [1, [Validators.required, Validators.min(1)]],
      reasonPreset: ['damaged', Validators.required],
      notes: [''],
    });
  }

  setupProductSearch(): void {
    this.subs.add(
      this.productSearch$
        .pipe(
          debounceTime(300),
          distinctUntilChanged(),
          switchMap((term) => {
            this.isSearchingProducts = true;
            return this.batchService.lookupProducts(term);
          })
        )
        .subscribe({
          next: (results) => {
            this.productSearchResults = results || [];
            this.isSearchingProducts = false;
          },
          error: () => {
            this.isSearchingProducts = false;
          },
        })
    );
  }

  onProductSearch(term: { term: string; items: any[] }): void {
    if (term?.term) {
      this.productSearch$.next(term.term);
    }
  }

  onProductSelected(product: BatchProductLookup): void {
    if (!product) {
      this.selectedProductDetails = null;
      return;
    }
    this.selectedProductDetails = product;
    this.createForm.patchValue({
      productId: product.id,
      merchantId: product.merchantId,
      barcode: product.barcode || '',
      sku: product.sku || '',
      sellingPrice: product.price || null,
    });

    if (!this.createForm.get('batchNumber')?.value) {
      this.generateBatchNumber();
    }
  }

  generateBatchNumber(): void {
    const now = new Date();
    const yr = now.getFullYear();
    const mo = String(now.getMonth() + 1).padStart(2, '0');
    const rnd = Math.floor(1000 + Math.random() * 9000);
    this.createForm.patchValue({
      batchNumber: `BAT-${yr}${mo}-${rnd}`,
    });
  }

  setQuickExpiry(months: number): void {
    const d = new Date();
    d.setMonth(d.getMonth() + months);
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    this.createForm.patchValue({
      expirationDate: `${yyyy}-${mm}-${dd}`,
    });
  }

  loadMerchants(): void {
    this.batchService.lookupMerchants().subscribe({
      next: (data) => {
        this.merchantsList = data || [];
        this.syncMerchantsFromBatches();
      },
      error: () => {
        this.syncMerchantsFromBatches();
      },
    });
  }

  syncMerchantsFromBatches(): void {
    if (this.batches && this.batches.length > 0) {
      const existingIds = new Set(this.merchantsList.map((m) => m.id));
      const discovered: BatchMerchantLookup[] = [];
      for (const b of this.batches) {
        if (b.merchantId && !existingIds.has(b.merchantId)) {
          existingIds.add(b.merchantId);
          discovered.push({
            id: b.merchantId,
            title: b.merchantTitle || `Merchant #${b.merchantId}`,
          });
        }
      }
      if (discovered.length > 0) {
        this.merchantsList = [...this.merchantsList, ...discovered];
      }
    }
  }

  get allCount(): number {
    return this.batches.length;
  }
  get activeCount(): number {
    return this.batches.filter((b) => b.status === 0).length;
  }
  get nearExpiryCount(): number {
    return this.batches.filter((b) => b.isNearExpiry || (b.daysUntilExpiry !== undefined && b.daysUntilExpiry > 0 && b.daysUntilExpiry <= 7)).length;
  }
  get expiredCount(): number {
    return this.batches.filter((b) => b.isExpired || (b.daysUntilExpiry !== undefined && b.daysUntilExpiry <= 0)).length;
  }
  get quarantinedCount(): number {
    return this.batches.filter((b) => b.status === 3).length;
  }

  selectStatusTab(status: string): void {
    this.selectedStatus = status;
    this.page = 1;
    this.applyFilter();
  }

  computeKpisFromBatches(batches: ProductBatch[]): InventoryBatchKpi {
    const active = batches.filter((b) => b.status === 0 || b.statusName === 'Active');
    const nearExpiry = batches.filter(
      (b) => b.isNearExpiry || (b.daysUntilExpiry !== undefined && b.daysUntilExpiry > 0 && b.daysUntilExpiry <= 7)
    );
    const expired = batches.filter((b) => b.isExpired || (b.daysUntilExpiry !== undefined && b.daysUntilExpiry <= 0));
    const quarantined = batches.filter((b) => b.status === 3);
    const depleted = batches.filter((b) => b.status === 4);
    const onHand = batches.reduce((sum, b) => sum + (b.quantityOnHand || 0), 0);
    const available = batches.reduce((sum, b) => sum + (b.quantityAvailable || 0), 0);
    const reserved = batches.reduce((sum, b) => sum + (b.quantityReserved || 0), 0);

    return {
      totalBatches: batches.length,
      activeBatches: active.length,
      nearExpiryBatches: nearExpiry.length,
      expiredBatches: expired.length,
      quarantinedBatches: quarantined.length,
      depletedBatches: depleted.length,
      totalQuantityOnHand: onHand,
      totalQuantityAvailable: available,
      totalQuantityReserved: reserved,
    };
  }

  loadData(): void {
    this.isLoading = true;
    this.hasError = false;

    const mid =
      this.selectedMerchantFilter !== 'all'
        ? parseInt(this.selectedMerchantFilter, 10)
        : undefined;

    this.batchService.getBatches(mid).subscribe({
      next: (data) => {
        this.batches = data || [];
        this.kpis = this.computeKpisFromBatches(this.batches);
        this.alerts = this.batches.filter(
          (b) => b.isNearExpiry || b.isExpired || (b.daysUntilExpiry !== undefined && b.daysUntilExpiry <= 7)
        );
        this.syncMerchantsFromBatches();
        this.applyFilter();
        this.isLoading = false;
      },
      error: (err) => {
        this.isLoading = false;
        this.hasError = true;
        this.errorMessage =
          err?.error?.message || 'Failed to load inventory batches. Please verify server connection.';
      },
    });

    this.batchService.getAlerts(mid, 7).subscribe({
      next: (alerts) => {
        if (alerts && alerts.length > 0) {
          this.alerts = alerts;
        }
      },
    });
  }

  applyFilter(): void {
    let result = [...this.batches];

    if (this.selectedMerchantFilter !== 'all') {
      const mid = parseInt(this.selectedMerchantFilter, 10);
      result = result.filter((b) => b.merchantId === mid);
    }

    if (this.selectedStatus !== 'all') {
      const statusNum = parseInt(this.selectedStatus, 10);
      result = result.filter((b) => b.status === statusNum);
    }

    if (this.searchQuery.trim()) {
      const q = this.searchQuery.toLowerCase().trim();
      result = result.filter(
        (b) =>
          b.batchNumber?.toLowerCase().includes(q) ||
          b.barcode?.toLowerCase().includes(q) ||
          b.sku?.toLowerCase().includes(q) ||
          b.productTitle?.toLowerCase().includes(q) ||
          b.merchantTitle?.toLowerCase().includes(q) ||
          b.locationBin?.toLowerCase().includes(q)
      );
    }

    // Sorting
    switch (this.selectedSort) {
      case 'fefo': // Nearest expiry first
        result.sort((a, b) => new Date(a.expirationDate).getTime() - new Date(b.expirationDate).getTime());
        break;
      case 'expiry_desc': // Furthest expiry first
        result.sort((a, b) => new Date(b.expirationDate).getTime() - new Date(a.expirationDate).getTime());
        break;
      case 'stock_desc': // Highest available stock
        result.sort((a, b) => b.quantityAvailable - a.quantityAvailable);
        break;
      case 'newest': // Newest batch ID
        result.sort((a, b) => b.id - a.id);
        break;
    }

    this.filteredBatches = result;
    this.totalItems = result.length;
    this.page = 1;
    this.updatePagedSlice();
  }

  onPageChange(newPage: number): void {
    this.page = newPage;
    this.updatePagedSlice();
  }

  updatePagedSlice(): void {
    const startIndex = (this.page - 1) * this.pageSize;
    this.pagedBatches = this.filteredBatches.slice(startIndex, startIndex + this.pageSize);
  }

  openCreateModal(): void {
    this.selectedProductDetails = null;
    this.createForm.reset({
      initialQuantity: 1,
      costPrice: 0,
    });
    this.generateBatchNumber();
    // Default 6 months expiry
    this.setQuickExpiry(6);
    this.batchService.lookupProducts('').subscribe((res) => {
      this.productSearchResults = res || [];
    });
    this.modalService.open(this.createModal, { size: 'lg', centered: true });
  }

  openAdjustModal(batch: ProductBatch): void {
    this.selectedBatch = batch;
    this.adjustForm.reset({
      adjustmentType: 'deduct',
      quantity: 1,
      reasonPreset: 'damaged',
      notes: '',
    });
    this.modalService.open(this.adjustModal, { centered: true });
  }

  openPrintModal(batch: ProductBatch): void {
    this.printBatch = batch;
    this.modalService.open(this.printModal, { centered: true, size: 'md' });
  }

  printCurrentLabel(): void {
    window.print();
  }

  toggleQuarantine(batch: ProductBatch): void {
    const isQuarantined = batch.status === BatchStatus.Quarantined;
    const confirmMsg = isQuarantined
      ? `Release batch ${batch.batchNumber} from quarantine?`
      : `Quarantine batch ${batch.batchNumber}? It will no longer be reserved for orders.`;

    if (!confirm(confirmMsg)) return;

    this.batchService.toggleQuarantine(batch.id, !isQuarantined, 'Admin dashboard toggle').subscribe({
      next: () => {
        this.loadData();
      },
      error: (err) => {
        alert(err?.error?.message || 'Error updating quarantine status');
      },
    });
  }

  submitCreate(): void {
    if (this.createForm.invalid) {
      this.createForm.markAllAsTouched();
      return;
    }

    this.isSubmitting = true;
    const dto: CreateProductBatchDto = this.createForm.value;
    this.batchService.createBatch(dto).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.modalService.dismissAll();
        this.loadData();
      },
      error: (err) => {
        this.isSubmitting = false;
        alert(err?.error?.message || 'Error creating inventory batch');
      },
    });
  }

  submitAdjust(): void {
    if (this.adjustForm.invalid || !this.selectedBatch) return;

    const val = this.adjustForm.value;
    const qty = Math.abs(val.quantity);
    const delta = val.adjustmentType === 'deduct' ? -qty : qty;

    if (val.adjustmentType === 'deduct' && qty > this.selectedBatch.quantityAvailable) {
      alert(`Cannot deduct ${qty} items. Only ${this.selectedBatch.quantityAvailable} units are available.`);
      return;
    }

    const reasonText = `${val.reasonPreset}: ${val.notes || ''}`.trim();

    this.isSubmitting = true;
    const dto: StockAdjustmentDto = {
      batchId: this.selectedBatch.id,
      quantityDelta: delta,
      reason: reasonText,
    };

    this.batchService.adjustStock(dto).subscribe({
      next: () => {
        this.isSubmitting = false;
        this.modalService.dismissAll();
        this.loadData();
      },
      error: (err) => {
        this.isSubmitting = false;
        alert(err?.error?.message || 'Error adjusting batch stock');
      },
    });
  }

  getStatusBadgeClass(status: BatchStatus): string {
    switch (status) {
      case BatchStatus.Active:
        return 'badge-light-success text-success';
      case BatchStatus.NearExpiry:
        return 'badge-light-warning text-warning';
      case BatchStatus.Expired:
        return 'badge-light-danger text-danger';
      case BatchStatus.Quarantined:
        return 'badge-light-info text-info';
      case BatchStatus.Depleted:
        return 'badge-light-secondary text-muted';
      default:
        return 'badge-light-primary text-primary';
    }
  }
}
