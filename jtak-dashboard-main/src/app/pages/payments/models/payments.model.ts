import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Payment extends BaseModel {
  id: any;
  toUserId: any;
  toUser: any;
  byUserId: any;
  byUser: any;
  amount: any;
  newBalance: any;
  handoverDate: any;
  createdDate: any;
}
