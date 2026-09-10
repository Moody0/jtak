import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface OrdersDetails extends BaseModel {
    quantity: number;
    totalFinalPrice: number;
    orderDetailStatus: number;
    orderDetailStatusString: string;
    productTitle: string;
}
