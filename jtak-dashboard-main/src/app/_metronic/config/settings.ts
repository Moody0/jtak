export const ApplicationRoutes = Object.freeze({
  Empty: '',
  Root: '/',
  Users: 'users',
  Merchants: 'merchants',
  Products: 'products',
  Categories: 'categories',
  Dashboard: 'dashboard',
  Banners: 'banners',
  Orders: 'orders',
  Bills: 'bills',
  Auth: 'auth',
  Login: 'login',
  ForgotPassword: 'forgot-password',
  Edit: 'edit',
  Create: 'create',
  Payments: 'payments',
  Reviews: 'reviews',
  Notifications: 'notifications',
  Pages: 'pages',
  PrivacyPolicy: 'pages/PrivacyPolicy',
  Terms: 'pages/TermsAndConditions',
  PaymentTerms: 'pages/PaymentPolicy',
  About: 'pages/About',

});

export const ApplicationMenu = [
  {
    path: ApplicationRoutes.Dashboard,
    label: 'MENU.DASHBOARD',
    icon: 'fas fa-tachometer-alt',
  },
  {
    path: ApplicationRoutes.Merchants,
    label: 'MENU.MERCHANTS',
    icon: 'fas fa-user-tie',
  },
  {
    path: ApplicationRoutes.Users,
    label: 'MENU.USERS',
    icon: 'fas fa-users',
  },
  {
    path: ApplicationRoutes.Categories,
    label: 'MENU.CATEGORIES',
    icon: 'fas fa-tags',
  },
  {
    path: ApplicationRoutes.Products,
    label: 'MENU.PRODUCTS',
    icon: 'fas fa-box',
  },
  {
    path: ApplicationRoutes.Banners,
    label: 'MENU.BANNERS',
    icon: 'fas fa-ad',
  },
  {
    path: ApplicationRoutes.Orders,
    label: 'MENU.ORDERS',
    icon: 'fas fa-shopping-cart',
  },
  {
    path: ApplicationRoutes.Payments,
    label: 'MENU.PAYMENTS',
    icon: 'fas fa-money-check-alt',
  },
  {
    path: ApplicationRoutes.Bills,
    label: 'MENU.BILLS',
    icon: 'fas fa-money-bill',
  },
  {
    path: ApplicationRoutes.Reviews,
    label: 'MENU.REVIEWS',
    icon: 'fas fa-star',
  },
  {
    path: ApplicationRoutes.Notifications,
    label: 'MENU.NOTIFICATIONS',
    icon: 'fas fa-bell',
  },
  {
    path: ApplicationRoutes.Terms,
    label: 'MENU.TERMS',
    icon: 'fas fa-file',
  },
  {
    path: ApplicationRoutes.About,
    label: 'MENU.ABOUT',
    icon: 'fas fa-file',
  },
  //{
  //  path: ApplicationRoutes.PaymentTerms,
  //  label: 'MENU.PAYMENTTERMS',
  //  icon: 'fas fa-file',
  //},
  //{
  //  path: ApplicationRoutes.PrivacyPolicy,
  //  label: 'MENU.PRIVACYPOLICY',
  //  icon: 'fas fa-file',
  //},
];

export const AppUserRoleMap = {
  '0': 'Admin',
  '1': 'Customer',
  '2': 'Merchant',
  '3': 'Delivery',
};

export const ApplicationMenuGroups = [
  { label: 'Overview', items: ApplicationMenu.slice(0, 1) },
  { label: 'Operations', items: ApplicationMenu.slice(1, 9) },
  { label: 'Engagement', items: ApplicationMenu.slice(9, 11) },
  { label: 'Content', items: ApplicationMenu.slice(11) },
];
