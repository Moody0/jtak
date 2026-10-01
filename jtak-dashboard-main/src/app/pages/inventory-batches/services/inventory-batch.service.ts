import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map, tap } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import {
  ProductBatch,
  CreateProductBatchDto,
  StockAdjustmentDto,
  BatchStatus,
  InventoryBatchKpi,
  BatchProductLookup,
  BatchMerchantLookup,
  QuarantineBatchDto,
} from '../models/product-batch.model';

@Injectable({
  providedIn: 'root',
})
export class InventoryBatchService {
  private readonly baseUrl = `${environment.apiUrl}/Admin/Batches`;
  private cachedMerchants: BatchMerchantLookup[] | null = null;
  private cachedBatches: ProductBatch[] | null = null;

  constructor(private http: HttpClient) {}

  getCachedBatches(): ProductBatch[] | null {
    return this.cachedBatches;
  }

  getBatches(
    merchantId?: number,
    productId?: number,
    status?: BatchStatus,
    searchTerm?: string
  ): Observable<ProductBatch[]> {
    let url = `${this.baseUrl}?`;
    if (merchantId) url += `merchantId=${merchantId}&`;
    if (productId) url += `productId=${productId}&`;
    if (status !== undefined && status !== null) url += `status=${status}&`;
    if (searchTerm) url += `searchTerm=${encodeURIComponent(searchTerm)}&`;
    return this.http.get<ProductBatch[]>(url).pipe(
      tap((batches) => {
        if (!merchantId && !productId && status === undefined && !searchTerm) {
          this.cachedBatches = batches;
        }
      })
    );
  }

  getKpis(merchantId?: number): Observable<InventoryBatchKpi | null> {
    // Handled reactively from batches to avoid unnecessary 400 Bad Request calls
    return of(null);
  }

  getAlerts(merchantId?: number, daysThreshold: number = 7): Observable<ProductBatch[]> {
    let url = `${this.baseUrl}/Alerts?daysThreshold=${daysThreshold}`;
    if (merchantId) url += `&merchantId=${merchantId}`;
    return this.http.get<ProductBatch[]>(url).pipe(
      catchError(() => of([]))
    );
  }

  lookupProducts(search?: string, merchantId?: number): Observable<BatchProductLookup[]> {
    const filter: any = {};
    if (merchantId) filter.merchantId = merchantId;
    if (search) filter.title = search;

    return this.http
      .post<any>(`${environment.apiUrl}/Admin/Products/DataTable`, {
        pageNumber: 1,
        pageSize: 100,
        filter,
      })
      .pipe(
        map((res) =>
          (res?.items || []).map((p: any) => ({
            id: p.id,
            title: p.title || `Product #${p.id}`,
            barcode: p.barcode || '',
            sku: p.sku || '',
            merchantId: p.merchantId || 0,
            merchantTitle: p.merchantTitle || '',
            price: p.price || 0,
            photo: p.photo,
          }))
        ),
        catchError(() => of([]))
      );
  }

  lookupMerchants(): Observable<BatchMerchantLookup[]> {
    if (this.cachedMerchants && this.cachedMerchants.length > 0) {
      return of(this.cachedMerchants);
    }
    return this.http
      .get<BatchMerchantLookup[]>(`${this.baseUrl}/Lookup/Merchants`)
      .pipe(
        tap((data) => {
          if (data && data.length > 0) {
            this.cachedMerchants = data;
          }
        }),
        catchError(() => {
          return this.http
            .get<any[]>(`${environment.apiUrl}/Admin/Users/Merchants`)
            .pipe(
              map((users) =>
                (users || []).map((u: any) => ({
                  id: u.id,
                  title: u.fullName || u.title || `Merchant #${u.id}`,
                }))
              ),
              tap((data) => {
                if (data && data.length > 0) {
                  this.cachedMerchants = data;
                }
              }),
              catchError(() => of([]))
            );
        })
      );
  }

  toggleQuarantine(batchId: number, quarantine: boolean, reason?: string): Observable<ProductBatch> {
    const dto: QuarantineBatchDto = { batchId, quarantine, reason };
    return this.http.post<ProductBatch>(`${this.baseUrl}/${batchId}/Quarantine`, dto);
  }

  getById(id: number): Observable<ProductBatch> {
    return this.http.get<ProductBatch>(`${this.baseUrl}/${id}`);
  }

  createBatch(dto: CreateProductBatchDto): Observable<ProductBatch> {
    return this.http.post<ProductBatch>(this.baseUrl, dto);
  }

  adjustStock(dto: StockAdjustmentDto): Observable<ProductBatch> {
    return this.http.post<ProductBatch>(`${this.baseUrl}/Adjust`, dto);
  }
}
