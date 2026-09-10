import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Product extends BaseModel {
  title: string;
  description: string;
  photos: string;
  unit: string;
  active: boolean;
  isFeatured: boolean;
  productCategoryId: number;
  productCategory: string;
}