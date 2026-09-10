import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Notification extends BaseModel {
    id: number;
    titleAr: string;
    titleEn: string;
    titleTr: string;
    title: string;
    textAr: string;
    textEn: string;
    textTr: string;
    text: string;
    notificationType: number,
    image: string;
    url: string;
}