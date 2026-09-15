export interface RestaurantCategoryItem {
  id: number;
  title: string;
  titleEn?: string;
  image: string;
  order: number;
  active: boolean;
  filterTag: string;

  /**
   * Catalog category this entry stands for. This is the real link: the
   * merchants behind it are the ones that actually sell in it. Entries without
   * one fall back to matching on filterTag.
   */
  productCategoryId?: number | null;

  /** Live merchant count from the backend. Zero means customers won't see it. */
  merchantCount?: number;
}

/** A category the admin can point an entry at, with its merchant count. */
export interface RestaurantCategoryTarget {
  id: number;
  title: string;
  parentTitle?: string | null;
  merchantCount: number;
}

export interface RestaurantCategoriesSectionConfig {
  sectionTitle: string;
  sectionTitleEn: string;
  /** Heading for the same categories where they appear as a strip on Home. */
  homeSectionTitle: string;
  homeSectionTitleEn: string;
  enabled: boolean;
  /** Whether the Home strip appears at all. */
  showOnHome: boolean;
  items: RestaurantCategoryItem[];
}

export interface AdminRestaurantCategoriesResponse {
  sectionTitle: string;
  sectionTitleEn: string;
  homeSectionTitle: string;
  homeSectionTitleEn: string;
  enabled: boolean;
  showOnHome: boolean;
  availableCategories: RestaurantCategoryTarget[];
  totalCount: number;
  activeCount: number;
  items: RestaurantCategoryItem[];
}
