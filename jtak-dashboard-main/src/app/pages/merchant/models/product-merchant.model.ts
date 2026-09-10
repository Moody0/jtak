export interface ProductMerchant {
  merchantId: number;
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
  categoryParentId: number | null;
  categoryActive: boolean;
  categoryIcon: string;
  profitOutOfMerchantPricePercent: number;
  profitOutOfMerchantPrice: number
  merchantProfit: number;
  merchantPrice: number;
  additionalProfitPercent: number;
  additionalProfit: number;
  discount: number;
  price: number;
  finalPrice: number;
  isSelected: boolean;
}
