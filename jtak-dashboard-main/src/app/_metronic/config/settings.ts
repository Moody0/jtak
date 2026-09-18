export const ApplicationRoutes = Object.freeze({
  Empty: '',
  Root: '/',
  Users: 'users',
  Merchants: 'merchants',
  Products: 'products',
  Categories: 'categories',
  Dashboard: 'dashboard',
  PopularProducts: 'popular-products',
  HomeCategories: 'home-categories',
  RestaurantCategories: 'restaurant-categories',
  Banners: 'banners',
  Orders: 'orders',
  Bills: 'bills',
  Reconciliation: 'reconciliation',
  InventoryBatches: 'inventory-batches',
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
  About: 'pages/About',
  AuditLogs: 'audit-logs',
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
    path: ApplicationRoutes.Reconciliation,
    label: 'MENU.RECONCILIATION',
    icon: 'fas fa-cash-register',
  },
  {
    path: ApplicationRoutes.InventoryBatches,
    label: 'MENU.INVENTORY_BATCHES',
    icon: 'fas fa-warehouse',
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
    path: ApplicationRoutes.About,
    label: 'MENU.ABOUT',
    icon: 'fas fa-info-circle',
  },
  {
    path: ApplicationRoutes.RestaurantCategories,
    label: 'MENU.RESTAURANT_CATEGORIES',
    icon: 'fas fa-utensils',
  },
  {
    path: ApplicationRoutes.AuditLogs,
    label: 'MENU.AUDIT_LOGS',
    icon: 'fas fa-shield-alt',
  },
];

export const AppUserRoleMap = {
  '0': 'Admin',
  '1': 'Customer',
  '2': 'Merchant',
  '3': 'Delivery',
};

export const ApplicationMenuGroups = [
  {
    label: 'MENU.GROUPS.OVERVIEW',
    items: [ApplicationMenu[0], ApplicationMenu[19]], // Dashboard, AuditLogs (سجل نشاط الإدارة)
  },
  {
    label: 'MENU.GROUPS.OPERATIONS',
    items: [ApplicationMenu[1], ApplicationMenu[2], ApplicationMenu[3]], // Orders, Reconciliation, InventoryBatches
  },
  {
    label: 'MENU.GROUPS.CATALOG',
    items: [ApplicationMenu[4], ApplicationMenu[5], ApplicationMenu[6], ApplicationMenu[17], ApplicationMenu[7]], // Products, PopularProducts, Categories, RestaurantCategories, Merchants
  },
  {
    label: 'MENU.GROUPS.FINANCE',
    items: [ApplicationMenu[8], ApplicationMenu[9]], // Bills, Payments
  },
  {
    label: 'MENU.GROUPS.USERS',
    items: [ApplicationMenu[10], ApplicationMenu[14]], // Users & Couriers, Support Messages
  },
  {
    label: 'MENU.GROUPS.MARKETING',
    items: [ApplicationMenu[11], ApplicationMenu[12], ApplicationMenu[13], ApplicationMenu[15], ApplicationMenu[16]], // Banners, Notifications, Reviews, Terms, About
  },
];
