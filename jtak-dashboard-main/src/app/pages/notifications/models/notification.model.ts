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
    topic?: string;
    createdDate?: string;
}

export interface CampaignAudiences {
    customers: number;
    delivery: number;
    warehouse: number;
    pushConfigured: boolean;
}

export interface CampaignRequest {
    target: 'customers' | 'delivery' | 'warehouse';
    titleAr: string;
    textAr: string;
    image?: string;
    destination: 'home' | 'orders' | 'merchant' | 'favorites' | 'grocery' | 'restaurants' | 'errands' | 'finance' | 'products';
    destinationId?: number | null;
}

export interface CampaignResult {
    recipientAccounts: number;
    acceptedLanguages: number;
    failedLanguages: number;
    failureCode?: string;
    historyRetained?: boolean;
}
