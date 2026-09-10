import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Merchant extends BaseModel {
    id: string;
    fullName: string;
}
