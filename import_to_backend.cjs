const https = require('https');
const querystring = require('querystring');
const fs = require('fs');
const dns = require('dns');

function customLookup(hostname, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = {};
  }
  if (hostname === 'api.jtak.app') {
    if (options && options.all) {
      return callback(null, [{ address: '104.21.95.238', family: 4 }]);
    }
    return callback(null, '104.21.95.238', 4);
  }
  return dns.lookup(hostname, options, callback);
}

function request(method, path, token, body = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const headers = {
      'Host': 'api.jtak.app',
      'Accept': 'application/json',
    };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload, 'utf8');
    } else {
      headers['Content-Length'] = 0;
    }

    const req = https.request(
      'https://api.jtak.app' + path,
      {
        method,
        lookup: customLookup,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          resolve({ status: res.statusCode, data });
        });
      }
    );

    req.on('error', reject);
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

function getToken() {
  return new Promise((resolve, reject) => {
    const postData = querystring.stringify({
      grant_type: 'password',
      username: 'admin@jtak.app',
      password: 'P@ssw0rd',
      scope: 'offline_access profile roles phone email',
    });

    const req = https.request(
      'https://api.jtak.app/connect/token',
      {
        method: 'POST',
        lookup: customLookup,
        headers: {
          'Host': 'api.jtak.app',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(postData, 'utf8'),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.access_token) {
              resolve(json.access_token);
            } else {
              reject(new Error('No token: ' + data));
            }
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function run() {
  console.log('--- JTAK FULL PRODUCTS IMPORTER ---');
  console.log('1. Authenticating with backend...');
  const token = await getToken();
  console.log('Token acquired.');

  console.log('2. Loading clean import data from JSON...');
  const rawContent = fs.readFileSync('E:/work/jtak/clean_import_data.json', 'utf8').replace(/^\uFEFF/, '');
  const data = JSON.parse(rawContent);

  const bestMarketItems = data.BestMarket || [];
  const cloverMallItems = data.CloverMall || [];
  console.log(`Loaded ${bestMarketItems.length} Best Market items and ${cloverMallItems.length} Clover Mall items.`);

  console.log('3. Fetching and synchronizing categories...');
  const catRes = await request('POST', '/api/v1/Admin/ProductCategories/DataTable', token, {
    pageNumber: 0,
    pageSize: 500,
    sortField: 'id',
    sortOrder: 'asc',
  });
  const catJson = JSON.parse(catRes.data);
  const existingCategories = catJson.items || [];

  // Maps for fast category lookup
  // mainCategoryMap: Title -> id
  // subCategoryMap: `${MainId}_${SubTitle}` -> id
  const mainCatMap = new Map();
  const subCatMap = new Map();

  for (const c of existingCategories) {
    if (!c.parentId) {
      mainCatMap.set(c.title.trim(), c.id);
    }
  }
  for (const c of existingCategories) {
    if (c.parentId) {
      subCatMap.set(`${c.parentId}_${c.title.trim()}`, c.id);
    }
  }

  // Find all unique main and sub categories in our dataset
  const allItems = [...bestMarketItems, ...cloverMallItems];
  const uniquePairs = new Map(); // Main -> Set of subs

  for (const it of allItems) {
    const main = (it.MainCategory || 'عام').trim();
    const sub = (it.SubCategory || main).trim();
    if (!uniquePairs.has(main)) {
      uniquePairs.set(main, new Set());
    }
    uniquePairs.get(main).add(sub);
  }

  console.log(`Found ${uniquePairs.size} distinct main categories in dataset.`);

  for (const [mainTitle, subs] of uniquePairs.entries()) {
    let mainId = mainCatMap.get(mainTitle);
    if (!mainId) {
      process.stdout.write(`Creating Main Category: "${mainTitle}"... `);
      const createRes = await request('POST', '/api/v1/Admin/ProductCategories', token, {
        title: mainTitle,
        parentId: null,
        active: true,
      });
      mainId = parseInt(createRes.data);
      mainCatMap.set(mainTitle, mainId);
      console.log(`Created (ID: ${mainId})`);
    }

    for (const subTitle of subs) {
      const key = `${mainId}_${subTitle}`;
      let subId = subCatMap.get(key);
      if (!subId) {
        process.stdout.write(`  Creating Subcategory: "${subTitle}" under "${mainTitle}"... `);
        const subRes = await request('POST', '/api/v1/Admin/ProductCategories', token, {
          title: subTitle,
          parentId: mainId,
          active: true,
        });
        subId = parseInt(subRes.data);
        subCatMap.set(key, subId);
        console.log(`Created (ID: ${subId})`);
      }
    }
  }

  console.log('Categories synchronization complete.');

  // Helper to get subcategory ID
  function getCategoryId(mainTitle, subTitle) {
    const m = (mainTitle || 'عام').trim();
    const s = (subTitle || m).trim();
    const mainId = mainCatMap.get(m);
    if (!mainId) return null;
    const subId = subCatMap.get(`${mainId}_${s}`);
    return subId || mainId;
  }

  // 4. Import Products
  // Function to import products for a merchant
  async function importMerchantCatalog(merchantName, merchantId, items) {
    console.log(`\n========================================`);
    console.log(`IMPORTING: ${merchantName} (Merchant ID: ${merchantId})`);
    console.log(`Total items to import: ${items.length}`);
    console.log(`========================================`);

    const assignedProducts = [];
    let successCount = 0;
    let errCount = 0;
    const concurrency = 15;

    for (let i = 0; i < items.length; i += concurrency) {
      const chunk = items.slice(i, i + concurrency);
      const promises = chunk.map(async (item) => {
        try {
          const catId = getCategoryId(item.MainCategory, item.SubCategory);
          const title = item.TitleAr || item.TitleEn;
          const desc = item.DescriptionAr || item.DescriptionEn || title;

          const res = await request('POST', '/api/v1/Admin/Products', token, {
            title: title,
            titleEn: item.TitleEn || title,
            description: desc,
            descriptionEn: item.DescriptionEn || desc,
            unit: item.Unit || 'قطعة',
            photos: item.PhotoUrl || '',
            productCategoryId: catId,
            active: true,
            isFeatured: true,
          });

          if (res.status === 200) {
            const productId = parseInt(res.data);
            if (productId > 0) {
              const price = item.PriceUsd || 0;
              const origPrice = item.OriginalPriceUsd || 0;
              const discount = origPrice > price ? origPrice - price : 0;

              assignedProducts.push({
                productId: productId,
                merchantPrice: price,
                originalPrice: origPrice,
                discount: discount,
                profitOutOfMerchantPricePercent: 0,
                additionalProfitPercent: 0,
              });
              successCount++;
              return;
            }
          }
          errCount++;
        } catch (e) {
          errCount++;
        }
      });

      await Promise.all(promises);
      const totalDone = successCount + errCount;
      process.stdout.write(`Progress: ${totalDone}/${items.length} items (${Math.round((totalDone / items.length) * 100)}%) - Success: ${successCount}\r`);
    }

    console.log(`\nCreated ${successCount} products in Catalog_Products (Errors: ${errCount}).`);

    // Assign products to merchant with prices
    console.log(`Assigning ${assignedProducts.length} prices to ${merchantName} (Merchant ID: ${merchantId})...`);
    const assignChunkSize = 250;
    for (let j = 0; j < assignedProducts.length; j += assignChunkSize) {
      const assignChunk = assignedProducts.slice(j, j + assignChunkSize);
      const assignRes = await request('PUT', `/api/v1/Admin/Merchants/Products/${merchantId}`, token, assignChunk);
      if (assignRes.status !== 200) {
        console.warn(`Warning: assign batch ${j} status ${assignRes.status}: ${assignRes.data}`);
      }
    }
    console.log(`Completed assigning products to ${merchantName}.`);
  }

  // Import Best Market
  await importMerchantCatalog('Best Market', 18, bestMarketItems);

  // Import Clover Mall
  await importMerchantCatalog('Clover Mall', 19, cloverMallItems);

  console.log('\n========================================');
  console.log('VERIFYING IMPORT RESULTS:');
  console.log('========================================');

  const finalProds = await request('POST', '/api/v1/Admin/Products/DataTable', token, {
    pageNumber: 0,
    pageSize: 1,
    sortField: 'id',
    sortOrder: 'desc',
  });
  const finalJson = JSON.parse(finalProds.data);
  console.log(`Total Products in /products: ${finalJson.totalRecords}`);

  const p18 = await request('GET', '/api/v1/Admin/Merchants/Products/18', token);
  const json18 = JSON.parse(p18.data);
  const priced18 = json18.filter((p) => p.merchantPrice && p.merchantPrice > 0);
  console.log(`Best Market (ID 18) total priced products: ${priced18.length} / ${json18.length}`);

  const p19 = await request('GET', '/api/v1/Admin/Merchants/Products/19', token);
  const json19 = JSON.parse(p19.data);
  const priced19 = json19.filter((p) => p.merchantPrice && p.merchantPrice > 0);
  console.log(`Clover Mall (ID 19) total priced products: ${priced19.length} / ${json19.length}`);

  console.log('\nIMPORT COMPLETED SUCCESSFULLY!');
}

run().catch((e) => {
  console.error('Fatal import error:', e);
  process.exit(1);
});
