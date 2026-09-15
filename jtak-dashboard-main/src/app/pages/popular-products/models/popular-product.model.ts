export interface AdminPopularProductItem {
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

export interface PopularProductItemConfig {
  productId: number;
  order: number;
  active: boolean;
  customBadge?: string;
  customTitle?: string;
}

export interface PopularSectionConfig {
  mode: 'Manual' | 'Hybrid' | 'Auto';
  sectionTitle: string;
  sectionTitleEn: string;
  maxItems: number;
  enabled: boolean;
  items: PopularProductItemConfig[];
}

export interface AdminPopularSectionResponse {
  mode: 'Manual' | 'Hybrid' | 'Auto';
  sectionTitle: string;
  sectionTitleEn: string;
  maxItems: number;
  enabled: boolean;
  items: AdminPopularProductItem[];
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
