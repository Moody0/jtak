import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Product extends BaseModel {
  title: string;
  barcode?: string | null;
  description: string;
  photos: string;
  unit: string;
  active: boolean;
  isPublishedToCustomer?: boolean | null;
  isFeatured: boolean;
  productCategoryId: number;
  productCategory: string;
  parentCategoryId?: number | null;
  parentCategoryTitle?: string;
  categoryHierarchy?: string;
  merchantId?: number;
  merchantTitle?: string;
  price?: number | null;
  priceUsd?: number | null;
  originalPrice?: number | null;
  discount?: number | null;
  discountPercent?: number | null;
  profitOutOfMerchantPricePercent?: number | null;
  currency?: number;
}
