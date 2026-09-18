import { BaseModel } from "src/app/_metronic/shared/crud-table";

export interface Balance {
    id: string;
    entityId?: number;
    name: string;
    phone?: string;
    productsCount?: number;
    amount: number;
    pendingAmount?: number;
    wagesAmount?: number;
}