const fs = require('fs');

console.log('=== CONTRACT VERIFICATION: OrderDetailStatus Enum Across Ecosystem ===\n');

// 1. Backend
const backendFile = 'D:/work/jtak/jtak-backend-main/Modules/Orders/Modules.Orders.Entities/OrderStatus.cs';
const backendContent = fs.readFileSync(backendFile, 'utf8');
console.log('[1] Backend OrderStatus.cs:');
const backendMatches = [...backendContent.matchAll(/([A-Za-z0-9_]+)\s*=\s*([0-9]+)/g)];
const backendMap = {};
backendMatches.forEach(m => {
  // Only order detail statuses
  if (['Pending', 'MerchantAccepted', 'ShippingStarted', 'Delivered', 'MerchantRejected', 'CustomerPending', 'CustomerCanceled', 'DeliveryCanceled', 'ReadyForPickup'].includes(m[1])) {
    backendMap[m[2]] = m[1];
  }
});
console.log(backendMap);

// 2. Dashboard
const dashboardFile = 'D:/work/jtak/jtak-dashboard-main/src/app/pages/orders/models/order-status.enum.ts';
const dashboardContent = fs.readFileSync(dashboardFile, 'utf8');
console.log('\n[2] Angular Dashboard order-status.enum.ts:');
const dashMatches = [...dashboardContent.matchAll(/([A-Za-z0-9_]+)\s*=\s*([0-9]+)/g)];
const dashMap = {};
dashMatches.forEach(m => {
  dashMap[m[2]] = m[1];
});
console.log(dashMap);

// 3. Customer App
const customerFile = 'D:/work/jtak/jtak-mobile-master/lib/src/core/enums/order_details_status_enum.dart';
const customerContent = fs.readFileSync(customerFile, 'utf8');
console.log('\n[3] Customer App order_details_status_enum.dart:');
const custMatches = [...customerContent.matchAll(/case\s+([0-9]+):\s+return\s+OrderDetailsStatus\.([A-Za-z0-9_]+);/g)];
const custMap = {};
custMatches.forEach(m => {
  custMap[m[1]] = m[2];
});
console.log(custMap);

// 4. Warehouse App
const whFile = 'D:/work/jtak/jtak-mobile-warehouse-master/lib/src/core/enums/order_details_status_enum.dart';
const whContent = fs.readFileSync(whFile, 'utf8');
console.log('\n[4] Warehouse App order_details_status_enum.dart:');
const whMatches = [...whContent.matchAll(/case\s+([0-9]+):\s+return\s+OrderDetailsStatus\.([A-Za-z0-9_]+);/g)];
const whMap = {};
whMatches.forEach(m => {
  whMap[m[1]] = m[2];
});
console.log(whMap);

// 5. Delivery App
const delFile = 'D:/work/jtak/jtak-mobile-delivery-master/lib/src/core/enums/order_details_status_enum.dart';
const delContent = fs.readFileSync(delFile, 'utf8');
console.log('\n[5] Delivery App order_details_status_enum.dart:');
const delMatches = [...delContent.matchAll(/case\s+([0-9]+):\s+return\s+OrderDetailsStatus\.([A-Za-z0-9_]+);/g)];
const delMap = {};
delMatches.forEach(m => {
  delMap[m[1]] = m[2];
});
console.log(delMap);

console.log('\n=== PARITY COMPARISON TABLE ===');
console.log('Value | Backend          | Dashboard        | Customer App     | Warehouse App    | Delivery App');
console.log('-----------------------------------------------------------------------------------------------');
for (let i = 0; i <= 8; i++) {
  const b = backendMap[i] || 'MISSING';
  const d = dashMap[i] || 'MISSING';
  const c = custMap[i] || 'MISSING';
  const w = whMap[i] || 'MISSING';
  const del = delMap[i] || 'MISSING';
  if (b !== 'MISSING' || d !== 'MISSING' || c !== 'MISSING' || w !== 'MISSING' || del !== 'MISSING') {
    console.log(`${i.toString().padEnd(5)} | ${b.padEnd(16)} | ${d.padEnd(16)} | ${c.padEnd(16)} | ${w.padEnd(16)} | ${del.padEnd(16)}`);
  }
}

const expected = {
  0: ['Pending', 'Pending', 'pending', 'pending', 'pending'],
  1: ['MerchantAccepted', 'MerchantAccepted', 'merchantAccepted', 'merchantAccepted', 'merchantAccepted'],
  2: ['ShippingStarted', 'ShippingStarted', 'shipping', 'shipping', 'shipping'],
  3: ['Delivered', 'Delivered', 'delivered', 'delivered', 'delivered'],
  4: ['MerchantRejected', 'MerchantRejected', 'merchantRejected', 'merchantRejected', 'merchantRejected'],
  5: ['CustomerPending', 'CustomerPending', 'customerPending', 'customerPending', 'customerPending'],
  6: ['CustomerCanceled', 'CustomerCanceled', 'customerCanceled', 'customerCanceled', 'customerCanceled'],
  7: ['DeliveryCanceled', 'DeliveryCanceled', 'deliveryCanceled', 'deliveryCanceled', 'deliveryCanceled'],
  8: ['ReadyForPickup', 'ReadyForPickup', 'readyForPickup', 'readyForPickup', 'readyForPickup'],
};
const actualMaps = [backendMap, dashMap, custMap, whMap, delMap];
const mismatch = Object.entries(expected).some(([value, names]) =>
  names.some((name, index) => actualMaps[index][value] !== name));
if (mismatch) {
  console.error('\nFAILED: OrderDetailStatus values are not aligned.');
  process.exitCode = 1;
} else {
  console.log('\nPASSED: OrderDetailStatus values are aligned across all five applications.');
}

console.log('\n=== TRUTH TABLE SIMULATION: Mixed-Item Permutations ===');

function resolveTruthTable(itemStatuses) {
  if (!itemStatuses || itemStatuses.length === 0) return 'Pending';

  const allRejected = itemStatuses.every(s => s === 4);
  if (allRejected) return 'MerchantRejected';

  const allTerminal = itemStatuses.every(s => s === 4 || s === 6 || s === 7);
  if (allTerminal) {
    if (itemStatuses.some(s => s === 4)) return 'MerchantRejected';
    if (itemStatuses.some(s => s === 7)) return 'DeliveryCanceled';
    return 'CustomerCanceled';
  }

  const active = itemStatuses.filter(s => s !== 4 && s !== 6 && s !== 7);

  if (active.length > 0 && active.every(s => s === 3)) return 'Delivered';
  if (active.some(s => s === 2)) return 'ShippingStarted';
  if (active.some(s => s === 8)) return 'ReadyForPickup';
  if (active.some(s => s === 1)) return 'MerchantAccepted';
  if (active.some(s => s === 5)) return 'CustomerPending';
  return 'Pending';
}

const testPermutations = [
  { name: 'All Delivered', items: [3, 3], expected: 'Delivered' },
  { name: 'Mixed Delivered + Rejected', items: [3, 4], expected: 'Delivered' },
  { name: 'Mixed Delivered + CustomerCanceled', items: [3, 6], expected: 'Delivered' },
  { name: 'Mixed Delivered + DeliveryCanceled', items: [3, 7], expected: 'Delivered' },
  { name: 'Mixed Shipping + Ready', items: [2, 8], expected: 'ShippingStarted' },
  { name: 'All ReadyForPickup', items: [8, 8], expected: 'ReadyForPickup' },
  { name: 'Mixed Ready + Accepted', items: [8, 1], expected: 'ReadyForPickup' },
  { name: 'Mixed Accepted + Pending', items: [1, 0], expected: 'MerchantAccepted' },
  { name: 'Mixed CustomerPending + Pending', items: [5, 0], expected: 'CustomerPending' },
  { name: 'All MerchantRejected', items: [4, 4], expected: 'MerchantRejected' },
  { name: 'All CustomerCanceled', items: [6, 6], expected: 'CustomerCanceled' },
  { name: 'Mixed Terminal (Rejected + Canceled)', items: [4, 6], expected: 'MerchantRejected' },
  { name: 'Mixed Terminal (DeliveryCanceled + CustomerCanceled)', items: [7, 6], expected: 'DeliveryCanceled' },
  { name: 'All Pending', items: [0, 0], expected: 'Pending' }
];

let allPassed = true;
for (const p of testPermutations) {
  const result = resolveTruthTable(p.items);
  const ok = result === p.expected;
  if (!ok) allPassed = false;
  console.log(`  ${ok ? '✓' : '✗'} [${p.name}]: items=[${p.items.join(', ')}] -> ${result} (expected: ${p.expected})`);
}

if (!allPassed) {
  console.error('\nFAILED: Truth table permutation tests failed.');
  process.exitCode = 1;
} else {
  console.log('\nPASSED: All 14 truth table permutations resolved correctly and identically.');
}
