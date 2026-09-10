const https = require('https');
const querystring = require('querystring');
const fs = require('fs');

function customLookup(hostname, options, callback) {
  if (typeof options === 'function') { callback = options; options = {}; }
  if (hostname === 'api.jtak.app') {
    if (options && options.all) return callback(null, [{ address: '104.21.95.238', family: 4 }]);
    return callback(null, '104.21.95.238', 4);
  }
  require('dns').lookup(hostname, options, callback);
}

function request(method, path, token, body = null) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const headers = { 'Host': 'api.jtak.app', 'Accept': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    if (payload) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(payload, 'utf8');
    } else {
      headers['Content-Length'] = 0;
    }

    const req = https.request('https://api.jtak.app' + path, {
      method, lookup: customLookup, headers
    }, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve({ status: res.statusCode, data }));
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function getToken() {
  return new Promise((resolve, reject) => {
    const postData = querystring.stringify({
      grant_type: 'password', username: 'admin@jtak.app', password: 'P@ssw0rd', scope: 'offline_access profile roles phone email'
    });
    const req = https.request('https://api.jtak.app/connect/token', {
      method: 'POST', lookup: customLookup,
      headers: { 'Host': 'api.jtak.app', 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(postData) }
    }, res => {
      let data = ''; res.on('data', c => data += c);
      res.on('end', () => resolve(JSON.parse(data).access_token));
    });
    req.on('error', reject); req.write(postData); req.end();
  });
}

async function run() {
  console.log('1. Authenticating...');
  const token = await getToken();

  console.log('2. Fetching DB products...');
  const body = { pageNumber: 0, pageSize: 6000, sortField: 'id', sortOrder: 'asc' };
  const prodRes = await request('POST', '/api/v1/Admin/Products/DataTable', token, body);
  const dbProducts = JSON.parse(prodRes.data).items || [];
  console.log(`Fetched ${dbProducts.length} products.`);

  console.log('3. Loading clean JSON...');
  const raw = fs.readFileSync('E:/work/jtak/clean_import_data.json', 'utf8').replace(/^\uFEFF/, '');
  const cleanData = JSON.parse(raw);
  const allClean = [...cleanData.BestMarket, ...cleanData.CloverMall];

  const toFix = [];
  for (let i = 0; i < dbProducts.length; i++) {
    const dbP = dbProducts[i];
    const cleanItem = allClean[i];
    if (dbP.title && dbP.title.includes('System.Xml')) {
      toFix.push({ dbP, cleanItem });
    }
  }

  console.log(`Found ${toFix.length} products with System.Xml to fix!`);

  let fixed = 0;
  let errors = 0;
  const concurrency = 20;

  for (let i = 0; i < toFix.length; i += concurrency) {
    const chunk = toFix.slice(i, i + concurrency);
    const promises = chunk.map(async ({ dbP, cleanItem }) => {
      try {
        const title = cleanItem.TitleAr || cleanItem.TitleEn;
        const desc = cleanItem.DescriptionAr || cleanItem.DescriptionEn || title;
        const res = await request('PUT', `/api/v1/Admin/Products/${dbP.id}`, token, {
          id: dbP.id,
          title: title,
          description: desc,
          unit: cleanItem.Unit || dbP.unit || 'قطعة',
          photos: cleanItem.PhotoUrl || dbP.photos || '',
          productCategoryId: dbP.productCategoryId,
          active: true,
        });
        if (res.status === 200) {
          fixed++;
        } else {
          errors++;
        }
      } catch (e) {
        errors++;
      }
    });

    await Promise.all(promises);
    process.stdout.write(`Progress: ${fixed + errors}/${toFix.length} - Fixed: ${fixed}, Errors: ${errors}\r`);
  }

  console.log(`\n\nCompleted! Fixed: ${fixed}, Errors: ${errors}`);

  // Also clear Merchant cache by updating merchant products
  console.log('Re-running assign_all_prices to update merchant product caches with clean names...');
  require('child_process').execSync('node e:\\work\\jtak\\assign_all_prices.cjs', { stdio: 'inherit' });
}

run().catch(console.error);
