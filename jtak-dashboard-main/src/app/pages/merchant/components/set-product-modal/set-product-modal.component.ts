import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import { ProductMerchant } from '../../models/product-merchant.model';
import { ProductMerchantsService } from '../../services/product-merchants.service';
import { FilesService } from 'src/app/modules/shared/services/files.service';

@Component({
  selector: 'app-set-product-modal',
  templateUrl: './set-product-modal.component.html',
  styleUrls: ['./set-product-modal.component.scss'],
})
export class SetProductModalComponent implements OnInit {
  @Input() mid: number;
  productMerchantsDraft: ProductMerchant[] = [];
  productMerchants: ProductMerchant[] = [];
  private subs = new SubSink();
  isLoading$: Observable<boolean>;
  saving = false;
  loadError = false;
  loaded = false;
  search = '';
  toggleAll = true;

  constructor(
    public productMerchantsService: ProductMerchantsService,
    public modal: NgbActiveModal,
    public filesService: FilesService,
    private toaster: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.productMerchantsService.isLoading$;
    this.subs.sink = this.productMerchantsService
      .getProducts(this.mid)
      .subscribe({ next: (result: any) => {
        this.loaded = true;
        if (result.length > 0) {
          const data = result.map((item: any) => ({
            ...item,
            isSelected: item.merchantId === +this.mid,
          }));

          const sortedData = this.sortProductMerchants(data);

          this.productMerchantsDraft = sortedData;
          this.productMerchants = sortedData;

          for (let product of this.productMerchants) {
            this.toggleAll = this.toggleAll && product.isSelected;
          }
        }
      }, error: () => { this.loadError = true; this.toaster.error('تعذر تحميل المنتجات. أعد فتح النافذة للمحاولة.'); } });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  onSearchChange(searchTerm: string) {
    this.productMerchantsDraft = this.productMerchants.filter(
      (item) =>
        (item.product || '').includes(searchTerm) ||
        (!!item.productCat1 && item.productCat1.includes(searchTerm)) ||
        (!!item.productCat2 && item.productCat2.includes(searchTerm))
    );
  }

  toggleAllChanged(event: any) {
    this.toggleAll = event.target.checked;

    for (let product of this.productMerchantsDraft) {
      product.isSelected = this.toggleAll;
    }
  }

  changeIsSelected(productId: number) {
    const updatedProductMerchants = [...this.productMerchants];
    const pi = this.productMerchants.findIndex(
      (i) => i.productId === productId
    );

    if (pi < 0) return;
    updatedProductMerchants[pi] = {
      ...updatedProductMerchants[pi],
      isSelected: !updatedProductMerchants[pi].isSelected,
    };

    this.productMerchants = this.sortProductMerchants(updatedProductMerchants);
    this.onSearchChange(this.search);
  }

  save() {
    if (this.saving || !this.loaded || this.loadError) return;
    this.saving = true;
    const data = this.productMerchants.filter((item) => item.isSelected);

    this.subs.sink = this.productMerchantsService
      .saveProducts(+this.mid, data)
      .subscribe({ next: () => this.modal.close(true), error: () => {
        this.saving = false; this.toaster.error('تعذر حفظ ربط المنتجات. حاول مرة أخرى.');
      } });
  }

  private sortProductMerchants(products: ProductMerchant[]) {
    return products.sort(function (x, y) {
      return x.isSelected === y.isSelected ? 0 : x.isSelected ? -1 : 1;
    });
  }
}
