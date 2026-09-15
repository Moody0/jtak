export enum BatchStatus {
  Active = 0,
  NearExpiry = 1,
  Expired = 2,
  Quarantined = 3,
  Depleted = 4,
}

export interface ProductBatch {
  id: number;
  productId: number;
  productTitle: string;
  merchantId: number;
  merchantTitle: string;
  batchNumber: string;
  lotNumber: string;
  barcode: string;
  sku: string;
  locationBin: string;
  manufactureDate?: string;
  expirationDate: string;
  quantityOnHand: number;
  quantityReserved: number;
  quantityAvailable: number;
  costPrice: number;
  sellingPrice?: number;
  status: BatchStatus;
  statusName: string;
  daysUntilExpiry: number;
  isExpired: boolean;
  isNearExpiry: boolean;
  notes?: string;
}

export interface CreateProductBatchDto {
  productId: number;
  merchantId: number;
  batchNumber: string;
  lotNumber?: string;
  barcode: string;
  sku?: string;
  locationBin?: string;
  manufactureDate?: string;
  expirationDate: string;
  initialQuantity: number;
  costPrice: number;
  sellingPrice?: number;
  notes?: string;
}

export interface StockAdjustmentDto {
  batchId: number;
  quantityDelta: number;
  reason: string;
}

export interface InventoryBatchKpi {
  totalBatches: number;
  activeBatches: number;
  nearExpiryBatches: number;
  expiredBatches: number;
  quarantinedBatches: number;
  depletedBatches: number;
  totalQuantityOnHand: number;
  totalQuantityReserved: number;
  totalQuantityAvailable: number;
}

export interface BatchProductLookup {
  id: number;
  title: string;
  barcode: string;
  sku: string;
  merchantId: number;
  merchantTitle: string;
  price: number;
  photo?: string;
}

export interface BatchMerchantLookup {
  id: number;
  title: string;
}

export interface QuarantineBatchDto {
  batchId: number;
  quarantine: boolean;
  reason?: string;
}
