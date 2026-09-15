import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Merchant extends BaseModel {
  id: number;
  title: string;
  shortDescription: string;
  description: string;
  ibaN1Title: string;
  ibaN1: string;
  phone1: string;
  phone2: string;
  address: string;
  shippingCoverageInMeters: number;
  profitOutOfMerchantPricePercent: number;
  lng: number;
  lat: number;
  active: boolean;
  merchantKind: number;
  deliveryTime?: string;
  deliveryFee?: number;
  minOrderAmount?: number;
  workingHours?: string;
  ownerId: string;
  owner: string;
  photo: string;
}
