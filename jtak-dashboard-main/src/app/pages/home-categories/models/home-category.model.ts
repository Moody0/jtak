/**
 * Where a home tile takes the customer. Stored explicitly so the apps route on
 * data rather than trying to recognise the words in a category's title.
 */
export enum HomeCategoryLinkType {
  ProductCategory = 0,
  MerchantKind = 1,
  Merchant = 2,
  Search = 3,
  MerchantCategory = 4,
  ErrandRequests = 5,
}

export const LINK_TYPE_LABELS: { value: HomeCategoryLinkType; label: string; hint: string }[] = [
  {
    value: HomeCategoryLinkType.ProductCategory,
    label: 'قسم من الأقسام',
    hint: 'الاسم والصورة للعرض فقط؛ العميل يفتح القسم المحدد أدناه مع منتجاته والمتاجر التي تبيعه.',
  },
  {
    value: HomeCategoryLinkType.MerchantCategory,
    label: 'قسم داخل متجر محدد',
    hint: 'يفتح قسماً معيناً داخل متجر أو سوبرماركت أو مطعم محدد',
  },
  {
    value: HomeCategoryLinkType.MerchantKind,
    label: 'نوع متاجر',
    hint: 'يفتح قائمة بكل المتاجر من هذا النوع، مثل كل المطاعم',
  },
  {
    value: HomeCategoryLinkType.Merchant,
    label: 'متجر محدد',
    hint: 'يفتح متجراً واحداً مباشرة',
  },
  {
    value: HomeCategoryLinkType.Search,
    label: 'كلمة بحث',
    hint: 'يفتح نتائج البحث عن كلمة محددة',
  },
  {
    value: HomeCategoryLinkType.ErrandRequests,
    label: 'طلبات',
    hint: 'يفتح نموذج طلب غرض من خارج الأقسام والمتاجر المعروضة',
  },
];

export interface HomeCategoryTile {
  id?: string;
  title: string;
  titleEn?: string | null;
  imageUrl?: string | null;
  order: number;
  active: boolean;
  linkType: HomeCategoryLinkType;
  productCategoryId?: number | null;
  secondaryProductCategoryId?: number | null;
  merchantKind?: number | null;
  restaurantCategoryId?: number | null;
  merchantId?: number | null;
  searchTerm?: string | null;
}

export interface HomeCategoriesConfig {
  enabled: boolean;
  sectionTitle: string;
  sectionTitleEn: string;
  maxItems: number;
  errandRequestsTileInitialized?: boolean;
  tiles: HomeCategoryTile[];
}

/** A tile with its destination resolved, as the app receives it. */
export interface ResolvedHomeCategoryTile extends HomeCategoryTile {
  targetLabel?: string | null;
  secondaryTargetCategoryTitle?: string | null;
  targetExists: boolean;
  hasAvailableContent: boolean;
  availableProductCount: number;
  availableMerchantCount: number;
  availabilityMessage?: string | null;
}

export interface HomeCategoryTarget {
  id: number;
  title: string;
  icon?: string | null;
  parentId?: number | null;
  parentTitle?: string | null;
  productCount: number;
  merchantCount: number;
  displayLabel?: string;
}

export interface HomeCategoryMerchant {
  isJtakMarket?: boolean;
  id: number;
  title: string;
  photo?: string | null;
  merchantKind: number;
  productCount: number;
  displayLabel?: string;
}

export interface HomeCategoryMerchantKind {
  value: number;
  name: string;
  merchantCount: number;
}

export interface HomeCategoriesAdminVm {
  config: HomeCategoriesConfig;
  tiles: ResolvedHomeCategoryTile[];
  availableCategories: HomeCategoryTarget[];
  availableMerchants: HomeCategoryMerchant[];
  availableMerchantKinds: HomeCategoryMerchantKind[];
  merchantCategoryMap?: { [merchantId: number]: number[] };
}

/** Arabic names for the backend MerchantKind values. */
export const MERCHANT_KIND_LABELS: { [key: number]: string } = {
  0: 'مطاعم',
  1: 'بقالة وماركت',
  2: 'صيدليات',
  3: 'متاجر أخرى',
  4: 'مستودعات',
};
