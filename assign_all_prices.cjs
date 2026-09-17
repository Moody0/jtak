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
  console.log('1. Authenticating...');
  const token = await getToken();
  console.log('Authenticated successfully.');

  console.log('2. Fetching all DB products...');
  const body = { pageNumber: 0, pageSize: 6000, sortField: 'id', sortOrder: 'asc' };
  const prodRes = await request('POST', '/api/v1/Admin/Products/DataTable', token, body);
  const prodData = JSON.parse(prodRes.data);
  const dbProducts = prodData.items || [];
  console.log(`Fetched ${dbProducts.length} products from backend database.`);

  console.log('3. Loading clean import data...');
  const raw = fs.readFileSync('E:/work/jtak/clean_import_data.json', 'utf8').replace(/^\uFEFF/, '');
  const data = JSON.parse(raw);

  const bmItems = data.BestMarket || [];
  const cmItems = data.CloverMall || [];

  console.log(`Clean data: Best Market = ${bmItems.length}, Clover Mall = ${cmItems.length}`);

  // We verified earlier:
  // Products 454 to 3647 (3,194 products) are Best Market
  // Products 3648 to 5660 (2,013 products) are Clover Mall
  const bmDbProducts = dbProducts.slice(0, 3194);
  const cmDbProducts = dbProducts.slice(3194);

  // Prepare Best Market payload
  const bmAssignPayload = bmDbProducts.map((p, idx) => {
    const rawItem = bmItems[idx];
    const price = rawItem ? (rawItem.PriceUsd || 0) : 0;
    const origPrice = rawItem ? (rawItem.OriginalPriceUsd || 0) : 0;
    const discount = origPrice > price ? origPrice - price : 0;

    return {
      productId: p.id,
      merchantPrice: price,
      priceUsd: price > 0 ? price : null,
      originalPrice: origPrice,
      discount: discount,
      profitOutOfMerchantPricePercent: 0,
      additionalProfitPercent: 0,
    };
  });

  // Prepare Clover Mall payload
  const cmAssignPayload = cmDbProducts.map((p, idx) => {
    const rawItem = cmItems[idx];
    const price = rawItem ? (rawItem.PriceUsd || 0) : 0;
    const origPrice = rawItem ? (rawItem.OriginalPriceUsd || 0) : 0;
    const discount = origPrice > price ? origPrice - price : 0;

    return {
      productId: p.id,
      merchantPrice: price,
      priceUsd: price > 0 ? price : null,
      originalPrice: origPrice,
      discount: discount,
      profitOutOfMerchantPricePercent: 0,
      additionalProfitPercent: 0,
    };
  });

  console.log(`\n4. Assigning ${bmAssignPayload.length} products to Best Market (ID: 18) in single call...`);
  const bmStart = Date.now();
  const bmRes = await request('PUT', '/api/v1/Admin/Merchants/Products/18', token, bmAssignPayload);
  console.log(`Best Market assign response: HTTP ${bmRes.status} (took ${Date.now() - bmStart}ms) - Response: ${bmRes.data}`);

  console.log(`\n5. Assigning ${cmAssignPayload.length} products to Clover Mall (ID: 19) in single call...`);
  const cmStart = Date.now();
  const cmRes = await request('PUT', '/api/v1/Admin/Merchants/Products/19', token, cmAssignPayload);
  console.log(`Clover Mall assign response: HTTP ${cmRes.status} (took ${Date.now() - cmStart}ms) - Response: ${cmRes.data}`);

  console.log('\n6. Verifying assignments...');
  const v18Res = await request('GET', '/api/v1/Admin/Merchants/Products/18', token);
  const json18 = JSON.parse(v18Res.data);
  const priced18 = json18.filter(p => p.merchantPrice && p.merchantPrice > 0);
  console.log(`Best Market (18): ${priced18.length} / ${bmAssignPayload.length} assigned with price > 0`);

  const v19Res = await request('GET', '/api/v1/Admin/Merchants/Products/19', token);
  const json19 = JSON.parse(v19Res.data);
  const priced19 = json19.filter(p => p.merchantPrice && p.merchantPrice > 0);
  console.log(`Clover Mall (19): ${priced19.length} / ${cmAssignPayload.length} assigned with price > 0`);

  console.log('\nSample Best Market assigned item:');
  console.log(priced18[0]);

  console.log('\nSample Clover Mall assigned item:');
  console.log(priced19[0]);

  console.log('\nSUCCESS!');
}

run().catch(e => {
  console.error('Error assigning prices:', e);
  process.exit(1);
});
