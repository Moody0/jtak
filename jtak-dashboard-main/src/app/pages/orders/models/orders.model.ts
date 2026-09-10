import { BaseModel } from 'src/app/_metronic/shared/crud-table';
import { OrdersDetails as OrdersDetail } from './ordersDetails.model';

export interface Order extends BaseModel {
    id: number;
    user: string;
    userId: string;
    deliveryId: string;
    deliveryUser: string;
    purchaseDate: string;
    address: string;
    description: string;
    phonenumber: string;
    lat: number;
    lng: number;
    price: number;
    orderDetails: OrdersDetail[];
    createdDate: string;
    paymentMethod: number;
}
