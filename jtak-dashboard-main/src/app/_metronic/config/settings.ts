export const ApplicationRoutes = Object.freeze({
  Empty: '',
  Root: '/',
  Users: 'users',
  Merchants: 'merchants',
  Products: 'products',
  Categories: 'categories',
  Dashboard: 'dashboard',
  PopularProducts: 'popular-products',
  MarketBestSelling: 'market-best-selling',
  HomeCategories: 'home-categories',
  RestaurantCategories: 'restaurant-categories',
  Banners: 'banners',
  Orders: 'orders',
  ErrandRequests: 'support-messages/errands',
  Bills: 'bills',
  Reconciliation: 'reconciliation',
  CaptainSettlements: 'captain-settlements',
  Auth: 'auth',
  Login: 'login',
  ForgotPassword: 'forgot-password',
  Edit: 'edit',
  Create: 'create',
  Payments: 'payments',
  Reviews: 'reviews',
  SupportMessages: 'support-messages',
  Notifications: 'notifications',
  Pages: 'pages',
  PrivacyPolicy: 'pages/PrivacyPolicy',
  Terms: 'pages/TermsAndConditions',
  PaymentTerms: 'pages/PaymentPolicy',
  AuditLogs: 'audit-logs',
  ContactSettings: 'settings/contact',
  TedallalSettings: 'settings/tedallal',
});

export const ApplicationMenu = [
  {
    path: ApplicationRoutes.Dashboard,
    label: 'MENU.DASHBOARD',
    icon: 'fas fa-tachometer-alt',
  },
  {
    path: ApplicationRoutes.Orders,
    label: 'MENU.ORDERS',
    icon: 'fas fa-shopping-bag',
  },
  {
    path: ApplicationRoutes.ErrandRequests,
    label: 'MENU.ERRAND_REQUESTS',
    icon: 'fas fa-clipboard-list',
  },
  {
    path: ApplicationRoutes.Reconciliation,
    label: 'MENU.RECONCILIATION',
    icon: 'fas fa-cash-register',
  },
  {
    path: ApplicationRoutes.Products,
    label: 'MENU.PRODUCTS',
    icon: 'fas fa-box-open',
  },
  {
    path: ApplicationRoutes.PopularProducts,
    label: 'MENU.POPULAR_PRODUCTS',
    icon: 'fas fa-fire-alt',
  },
  {
    path: ApplicationRoutes.MarketBestSelling,
    label: 'MENU.MARKET_BEST_SELLING',
    icon: 'fas fa-shopping-basket',
  },
  {
    path: ApplicationRoutes.Categories,
    label: 'MENU.CATEGORIES',
    icon: 'fas fa-tags',
  },
  {
    path: ApplicationRoutes.HomeCategories,
    label: 'MENU.HOME_CATEGORIES',
    icon: 'fas fa-th-large',
  },
  {
    path: ApplicationRoutes.Merchants,
    label: 'MENU.MERCHANTS',
    icon: 'fas fa-store',
  },
  {
    path: ApplicationRoutes.Bills,
    label: 'MENU.BILLS',
    icon: 'fas fa-file-invoice-dollar',
  },
  {
    path: ApplicationRoutes.Payments,
    label: 'MENU.PAYMENTS',
    icon: 'fas fa-hand-holding-usd',
  },
  {
    path: ApplicationRoutes.Users,
    label: 'MENU.USERS',
    icon: 'fas fa-users-cog',
  },
  {
    path: ApplicationRoutes.Banners,
    label: 'MENU.BANNERS',
    icon: 'fas fa-ad',
  },
  {
    path: ApplicationRoutes.Notifications,
    label: 'MENU.NOTIFICATIONS',
    icon: 'fas fa-bell',
  },
  {
    path: ApplicationRoutes.Reviews,
    label: 'MENU.REVIEWS',
    icon: 'fas fa-star',
  },
  {
    path: ApplicationRoutes.SupportMessages,
    label: 'MENU.SUPPORT_MESSAGES',
    icon: 'fas fa-headset',
  },
  {
    path: ApplicationRoutes.Terms,
    label: 'MENU.TERMS',
    icon: 'fas fa-file-contract',
  },
  {
    path: ApplicationRoutes.RestaurantCategories,
    label: 'MENU.RESTAURANT_CATEGORIES',
    icon: 'fas fa-utensils',
  },
  {
    path: ApplicationRoutes.ContactSettings,
    label: 'MENU.CONTACT_SETTINGS',
    icon: 'fas fa-headset',
  },
  {
    path: ApplicationRoutes.TedallalSettings,
    label: 'MENU.TEDALLAL_CARD',
    icon: 'fas fa-gift',
  },
  {
  path: ApplicationRoutes.AuditLogs,
    label: 'MENU.AUDIT_LOGS',
    icon: 'fas fa-shield-alt',
  },
  {
    path: ApplicationRoutes.PrivacyPolicy,
    label: 'MENU.PRIVACY',
    icon: 'fas fa-user-shield',
  },
  {
    path: ApplicationRoutes.PaymentTerms,
    label: 'MENU.PAYMENT_TERMS',
    icon: 'fas fa-file-invoice',
  },
];

export const AppUserRoleMap = {
  '0': 'Admin',
  '1': 'Customer',
  '2': 'Merchant',
  '3': 'Delivery',
};

// Keep one source of truth for the sidebar and the tabs within each workspace.
// Lookup by route avoids silently placing a page in the wrong section when the
// ApplicationMenu order changes.
const menuItem = (path: string) => {
  const item = ApplicationMenu.find((entry) => entry.path === path);
  if (!item) throw new Error(`Missing dashboard menu route: ${path}`);
  return item;
};

export const ApplicationMenuGroups = [
  {
    id: 'overview',
    label: 'MENU.GROUPS.OVERVIEW',
    description: 'MENU.GROUP_DESCRIPTIONS.OVERVIEW',
    icon: 'fas fa-home',
    items: [menuItem(ApplicationRoutes.Dashboard)],
  },
  {
    id: 'operations',
    label: 'MENU.GROUPS.OPERATIONS',
    description: 'MENU.GROUP_DESCRIPTIONS.OPERATIONS',
    icon: 'fas fa-shopping-bag',
    items: [menuItem(ApplicationRoutes.Orders), menuItem(ApplicationRoutes.ErrandRequests), menuItem(ApplicationRoutes.SupportMessages)],
  },
  {
    id: 'catalog',
    label: 'MENU.GROUPS.CATALOG',
    description: 'MENU.GROUP_DESCRIPTIONS.CATALOG',
    icon: 'fas fa-box-open',
    items: [menuItem(ApplicationRoutes.Products), menuItem(ApplicationRoutes.Categories), menuItem(ApplicationRoutes.RestaurantCategories), menuItem(ApplicationRoutes.Merchants)],
  },
  {
    id: 'storefront',
    label: 'MENU.GROUPS.CONTENT',
    description: 'MENU.GROUP_DESCRIPTIONS.CONTENT',
    icon: 'fas fa-mobile-alt',
    items: [menuItem(ApplicationRoutes.HomeCategories), menuItem(ApplicationRoutes.TedallalSettings), menuItem(ApplicationRoutes.PopularProducts), menuItem(ApplicationRoutes.MarketBestSelling), menuItem(ApplicationRoutes.Banners)],
  },
  {
    id: 'finance',
    label: 'MENU.GROUPS.FINANCE',
    description: 'MENU.GROUP_DESCRIPTIONS.FINANCE',
    icon: 'fas fa-wallet',
    items: [menuItem(ApplicationRoutes.Reconciliation), menuItem(ApplicationRoutes.Bills), menuItem(ApplicationRoutes.Payments)],
  },
  {
    id: 'people',
    label: 'MENU.GROUPS.USERS',
    description: 'MENU.GROUP_DESCRIPTIONS.USERS',
    icon: 'fas fa-users',
    items: [menuItem(ApplicationRoutes.Users), menuItem(ApplicationRoutes.Reviews), menuItem(ApplicationRoutes.Notifications)],
  },
  {
    id: 'system',
    label: 'MENU.GROUPS.SYSTEM',
    description: 'MENU.GROUP_DESCRIPTIONS.SYSTEM',
    icon: 'fas fa-cog',
    items: [menuItem(ApplicationRoutes.ContactSettings), menuItem(ApplicationRoutes.Terms), menuItem(ApplicationRoutes.PrivacyPolicy), menuItem(ApplicationRoutes.PaymentTerms), menuItem(ApplicationRoutes.AuditLogs)],
  },
];

export function findApplicationMenuLocation(url: string): {
  group: typeof ApplicationMenuGroups[number];
  item: typeof ApplicationMenu[number];
} | null {
  const currentPath = url.split('?')[0].split('#')[0];
  let match: { group: typeof ApplicationMenuGroups[number]; item: typeof ApplicationMenu[number] } | null = null;
  for (const group of ApplicationMenuGroups) {
    for (const item of group.items) {
      if (currentPath === `/${item.path}` || currentPath.startsWith(`/${item.path}/`)) {
        if (!match || item.path.length > match.item.path.length) match = { group, item };
      }
    }
  }
  return match;
}
