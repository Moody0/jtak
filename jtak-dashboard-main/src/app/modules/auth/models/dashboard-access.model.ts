export interface DashboardAccess {
  canAccess: boolean;
  isSuperAdmin: boolean;
  roleNames: string[];
  permissions: string[];
}

export function dashboardSection(url: string): string | null {
  const path = url.replace(/^\//, '').split(/[?#]/)[0];
  if (path.startsWith('support-messages/errands')) return 'orders';
  if (path.startsWith('settings/tedallal')) return 'storefront';
  const sections: Record<string, string> = {
    dashboard: 'dashboard', orders: 'orders', 'support-messages': 'support', reviews: 'support',
    merchants: 'catalog', products: 'catalog', categories: 'catalog', 'restaurant-categories': 'catalog',
    banners: 'storefront', 'home-categories': 'storefront', 'popular-products': 'storefront', 'market-best-selling': 'storefront',
    payments: 'finance', bills: 'finance', reconciliation: 'finance', 'captain-settlements': 'finance',
    users: 'users', notifications: 'communications', settings: 'settings', pages: 'settings', 'audit-logs': 'audit',
  };
  return sections[path.split('/')[0]] || null;
}
