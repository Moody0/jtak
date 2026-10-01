export interface AdminMarketBestSellingProductItem {
  productId: number;
  title: string;
  description?: string;
  photos?: string;
  unit?: string;
  price: number;
  finalPrice: number;
  categoryId: number;
  categoryTitle?: string;
  merchantId: number;
  merchantTitle?: string;
  merchantLogo?: string;
  order: number;
  active: boolean;
  productActive: boolean;
  customBadge?: string;
  customTitle?: string;
  realOrdersCount?: number;
}

export interface MarketBestSellingItemConfig {
  productId: number;
  order: number;
  active: boolean;
  customBadge?: string;
  customTitle?: string;
}

export interface MarketBestSellingSectionConfig {
  mode: 'Manual' | 'Hybrid' | 'Auto';
  sectionTitle: string;
  sectionTitleEn: string;
  maxItems: number;
  enabled: boolean;
  items: MarketBestSellingItemConfig[];
}

export interface AdminMarketBestSellingSectionResponse {
  mode: 'Manual' | 'Hybrid' | 'Auto';
  sectionTitle: string;
  sectionTitleEn: string;
  maxItems: number;
  enabled: boolean;
  items: AdminMarketBestSellingProductItem[];
}

export interface SearchProductCandidate {
  id: number;
  title: string;
  unit?: string;
  photos?: string;
  price: number;
  categoryId: number;
  categoryTitle?: string;
  merchantId: number;
  merchantTitle?: string;
  active: boolean;
  isAlreadyInPopular: boolean;
}
