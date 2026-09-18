import { Routes } from '@angular/router';

const Routing: Routes = [
  {
    path: 'dashboard',
    loadChildren: () =>
      import('./dashboard/dashboard.module').then((m) => m.DashboardModule),
  },
  {
    path: 'merchants',
    loadChildren: () =>
      import('./merchant/merchants.module').then((m) => m.MerchantsModule),
  },
  {
    path: 'users',
    loadChildren: () =>
      import('./users/users.module').then((m) => m.UsersModule),
  },
  {
    path: 'banners',
    loadChildren: () =>
      import('./banners/banners.module').then((m) => m.BannersModule),
  },
  {
    path: 'orders',
    loadChildren: () =>
      import('./orders/orders.module').then((m) => m.OrdersModule),
  },
  {
    path: 'payments',
    loadChildren: () =>
      import('./payments/payments.module').then((m) => m.PaymentsModule),
  },
  {
    path: 'reviews',
    loadChildren: () =>
      import('./product-reviews/product-reviews.module').then((m) => m.ReviewsModule),
  },
  {
    path: 'categories',
    loadChildren: () =>
      import('./categories/categories.module').then((m) => m.CategoriesModule),
  },
  {
    path: 'products',
    loadChildren: () =>
      import('./products/products.module').then((m) => m.ProductsModule),
  },
  {
    path: 'popular-products',
    loadChildren: () =>
      import('./popular-products/popular-products.module').then(
        (m) => m.PopularProductsModule
      ),
  },
  {
    path: 'home-categories',
    loadChildren: () =>
      import('./home-categories/home-categories.module').then(
        (m) => m.HomeCategoriesModule
      ),
  },
  {
    path: 'restaurant-categories',
    loadChildren: () =>
      import('./restaurant-categories/restaurant-categories.module').then(
        (m) => m.RestaurantCategoriesModule
      ),
  },
  {
    path: 'bills',
    loadChildren: () =>
      import('./bills/bills.module').then((m) => m.BillsModule),
  },
  {
    path: 'reconciliation',
    loadChildren: () =>
      import('./reconciliation/reconciliation.module').then((m) => m.ReconciliationModule),
  },
  {
    path: 'inventory-batches',
    loadChildren: () =>
      import('./inventory-batches/inventory-batches.module').then((m) => m.InventoryBatchesModule),
  },
  {
    path: 'audit-logs',
    loadChildren: () =>
      import('./audit-logs/audit-logs.module').then((m) => m.AuditLogsModule),
  },
  {
    path: 'notifications',
    loadChildren: () =>
      import('./notifications/notifications.module').then((m) => m.NotificationsModule),
  },
  {
    path: 'support-messages',
    loadChildren: () =>
      import('./support-messages/support-messages.module').then((m) => m.SupportMessagesModule),
  },
  {
    path: 'pages',
    loadChildren: () =>
      import('./pages/pages.module').then((m) => m.PagesModule),
  },
  {
    path: 'crafted/pages/profile',
    loadChildren: () =>
      import('../modules/profile/profile.module').then((m) => m.ProfileModule),
  },
  {
    path: 'crafted/account',
    loadChildren: () =>
      import('../modules/account/account.module').then((m) => m.AccountModule),
  },
  {
    path: '',
    redirectTo: '/dashboard',
    pathMatch: 'full',
  },
  {
    path: '**',
    redirectTo: 'error/404',
  },
];

export { Routing };
