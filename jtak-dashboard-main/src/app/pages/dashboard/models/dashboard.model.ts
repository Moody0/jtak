import { BaseModel } from "src/app/_metronic/shared/crud-table";

export interface Dashboard {
    productsCount: number,
    usersCount: number,
    ordersCount: number,
    billsCount: number,
    totalOrdersValue: number,
    merchantOrdersValue: number,
    jTakOrdersValue: number,
    jTakAdditionalOrdersValue: number,
    topProducts : TopProduct[]
}
export interface TopProduct {
    productId: number,
    productName: string,
    count: number
}