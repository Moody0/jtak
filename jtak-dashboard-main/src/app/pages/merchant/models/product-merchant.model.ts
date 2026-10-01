export interface ProductMerchant {
  merchantId: number;
  merchantKind?: number;
  productId: number;
  product: string;
  productPhotos: string;
  productCat1: string;
  productCat2: string;
  productDescription: string;
  productUnit: string;
  productCategoryId: number | null;
  productActive: boolean;
  productIsFeatured: boolean;
  hasRestaurantAssignment?: boolean;
  hasJtakMarketAssignment?: boolean;
  categoryParentId: number | null;
  categoryActive: boolean;
  categoryIcon: string;
  profitOutOfMerchantPricePercent: number;
  profitOutOfMerchantPrice: number
  merchantProfit: number;
  merchantPrice: number;
  priceUsd?: number | null;
  originalPrice?: number | null;
  discount: number;
  discountPercent?: number | null;
  maxOrderQuantity?: number | null;
  price: number;
  finalPrice: number;
  isSelected: boolean;
}
