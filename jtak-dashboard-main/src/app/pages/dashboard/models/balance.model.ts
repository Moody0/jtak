import { BaseModel } from "src/app/_metronic/shared/crud-table";

export interface Balance {
    id: string,
    name: string,
    productsCount: number,
    amount: number,
    pendingAmount: number,
    //"createdDate": "2022-04-18T13:10:48.919Z"
}