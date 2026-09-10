import { Component, OnInit, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { Observable } from 'rxjs';
import { ProductMerchant } from '../../models/product-merchant.model';
import { ProductMerchantsService } from '../../services/product-merchants.service';
import { FilesService } from 'src/app/modules/shared/services/files.service';

@Component({
  selector: 'app-set-product-modal',
  templateUrl: './set-product-modal.component.html',
  styles: [],
})
export class SetProductModalComponent implements OnInit {
  @Input() mid: number;
  productMerchantsDraft: ProductMerchant[] = [];
  productMerchants: ProductMerchant[] = [];
  private subs = new SubSink();
  isLoading$: Observable<boolean>;
  public percent: number;
  search = '';
  toggleAll = true;

  constructor(
    public productMerchantsService: ProductMerchantsService,
    public modal: NgbActiveModal,
    public filesService: FilesService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.productMerchantsService.isLoading$;
    this.productMerchantsService
      .getProducts(this.mid)
      .subscribe((result: any) => {
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
      });
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  onSearchChange(searchTerm: string) {
    this.productMerchantsDraft = this.productMerchants.filter(
      (item) =>
        item.product.includes(searchTerm) ||
        (item.productCat1 !== null && item.productCat1.includes(searchTerm)) ||
        (item.productCat2 !== null && item.productCat2.includes(searchTerm))
    );
  }

  toggleAllChanged(event: any) {
    this.toggleAll = event.target.checked;

    for (let product of this.productMerchants) {
      product.isSelected = this.toggleAll;
    }
  }

  onPercentChange(productId: number, event: any) {
    const updatedProductMerchants = [...this.productMerchants];
    const productIndex = this.productMerchants.findIndex(
      (item) => item.productId === productId
    );

    updatedProductMerchants[productIndex] = {
      ...updatedProductMerchants[productIndex],
      additionalProfitPercent: event.target.value,
    };
  }

  changeIsSelected(productId: number) {
    const updatedProductMerchants = [...this.productMerchants];
    const pi = this.productMerchants.findIndex(
      (i) => i.productId === productId
    );

    updatedProductMerchants[pi] = {
      ...updatedProductMerchants[pi],
      isSelected: !updatedProductMerchants[pi].isSelected,
    };

    this.productMerchants = this.sortProductMerchants(updatedProductMerchants);
  }

  save() {
    const data = this.productMerchants.filter((item) => item.isSelected);

    this.productMerchantsService
      .saveProducts(+this.mid, data)
      .subscribe((result) => {
        this.modal.close();
      });
  }

  private sortProductMerchants(products: ProductMerchant[]) {
    return products.sort(function (x, y) {
      return x.isSelected === y.isSelected ? 0 : x.isSelected ? -1 : 1;
    });
  }
}
