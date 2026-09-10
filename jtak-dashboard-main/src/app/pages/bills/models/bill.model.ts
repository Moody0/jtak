import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Bill extends BaseModel {
    id: number;
    merchantId: number;
    merchantTitle: string;
    merchantAmount: number;
    totalAmount: number;
    jTakAmount: number;
    jTakAdditionalAmount: number;
    paymentMethod: number;
    orderId: number;
    dueDate: string;
    isAddedToDues: boolean;
    createdDate: string;
}
