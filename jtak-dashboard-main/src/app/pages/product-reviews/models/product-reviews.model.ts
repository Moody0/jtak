import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface productReview extends BaseModel {
  id: any;
  reviewerId: any;
  productId: any;
  productTitle: any;
  productImage: any;
  rate: any;
  textReview: any;
  imageReview: any;
  isApproved: any;
  createdDate: any;
}