import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Banner extends BaseModel {
  id: string;
  title: string;
  description: string;
  order: number;
  url: string;
  active: boolean;
  featuredImage: string;
  createdDate: string;
  bannerLocation: number;
}
